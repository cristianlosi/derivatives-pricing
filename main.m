% =========================================================
%  ADVANCED DERIVATIVES ASSIGNMENT
%  Data di valutazione: 30/03/2026
%  Banca: Credit Agricole (ACAFP)
%  Gruppo: Cristian Losi, Marco Arienti, Matteo Ciotta
% =========================================================

%% LETTURA DATASET

clear
clc

Dataset = readtable("Dataset.xlsx", "VariableNamingRule", "preserve");
col1 = Dataset{:, 1};
sep_rows = find(isnan(col1));
% sep_rows(1)=1 (primo ERROR6), sep_rows(2)=52 (secondo ERROR6)
% Dati aprile: da riga 2 a riga 51
Dataset = Dataset(sep_rows(1)+1 : sep_rows(2)-1, :);

% Divido Call e Put
Calls_raw = Dataset(:, 1:7);
Puts_raw  = Dataset(:, 8:14);

% CALL
K_C   = double(Calls_raw{:,1});
Bid_C = double(Calls_raw{:,3});
Ask_C = double(Calls_raw{:,4});
IVM_C = double(Calls_raw{:,6});
Mid_C = (Bid_C + Ask_C) / 2;

% PUT
K_P   = double(Puts_raw{:,1});
Bid_P = double(Puts_raw{:,3});
Ask_P = double(Puts_raw{:,4});
IVM_P = double(Puts_raw{:,6});
Mid_P = (Bid_P + Ask_P) / 2;

% Rimuovo righe con NaN
valid_C = ~isnan(K_C) & ~isnan(Mid_C) & ~isnan(IVM_C);
valid_P = ~isnan(K_P) & ~isnan(Mid_P) & ~isnan(IVM_P);
K_C   = K_C(valid_C);
Mid_C = Mid_C(valid_C);
IVM_C = IVM_C(valid_C);
K_P   = K_P(valid_P);
Mid_P = Mid_P(valid_P);
IVM_P = IVM_P(valid_P);

%% PARAMETRI

S0    = 5520.34;        % EUROSTOXX50 al 30/03/2026
r     = 0.01934;        % Zero rate OIS 1M (mid), annualizzato
T     = 18/365;         % Maturity: scadenza 17 aprile 2026 (18 giorni)
q     = 0.02936;        % Dividend yield EUROSTOXX50 (Bloomberg, corrente)
DF_r  = exp(-r * T);    % Discount factor risk-free
DF_q  = exp(-q * T);    % Discount factor dividend

fprintf('=== PARAMETRI ===\n\n');
fprintf('S0 = %.2f\n', S0);
fprintf('r  = %.6f (%.4f%%)\n', r, r*100);
fprintf('T  = %.6f anni (%d giorni)\n', T, round(T*365));
fprintf('q  = %.6f (%.4f%%)\n', q, q*100);
fprintf('Forward = %.4f\n\n', S0 * exp((r-q)*T));

%% PUNTO 1: Vincoli di Merton, Monotonicita', Convessita'

fprintf('\n\n\n=== PUNTO 1: Vincoli di non arbitraggio ===\n\n');

% CALL
LB_C     = max(0, S0.*DF_q - K_C.*DF_r);
UB_C     = S0 .* DF_q;
Merton_C = (Mid_C >= LB_C) & (Mid_C <= UB_C);
Mono_C      = true(size(Mid_C));
Mono_C(2:end) = diff(Mid_C) <= 0;
Conv_C = true(size(Mid_C));
for i = 2:length(Mid_C)-1
    Conv_C(i) = (Mid_C(i+1) - 2*Mid_C(i) + Mid_C(i-1)) >= 0;
end

% PUT
LB_P     = max(0, K_P.*DF_r - S0.*DF_q);
UB_P     = K_P .* DF_r;
Merton_P = (Mid_P >= LB_P) & (Mid_P <= UB_P);
Mono_P      = true(size(Mid_P));
Mono_P(2:end) = diff(Mid_P) >= 0;
Conv_P = true(size(Mid_P));
for i = 2:length(Mid_P)-1
    Conv_P(i) = (Mid_P(i+1) - 2*Mid_P(i) + Mid_P(i-1)) >= 0;
end

Results_CALL = table(K_C, Mid_C, Merton_C, Mono_C, Conv_C, ...
    'VariableNames', {'Strike','Mid','Merton','Monotonicity','Convexity'});
Results_PUT  = table(K_P, Mid_P, Merton_P, Mono_P, Conv_P, ...
    'VariableNames', {'Strike','Mid','Merton','Monotonicity','Convexity'});
fprintf('CALL - Merton: %d/%d OK | Mono: %d/%d OK | Conv: %d/%d OK\n', ...
    sum(Merton_C), length(Merton_C), sum(Mono_C), length(Mono_C), sum(Conv_C), length(Conv_C));
fprintf('PUT  - Merton: %d/%d OK | Mono: %d/%d OK | Conv: %d/%d OK\n\n', ...
    sum(Merton_P), length(Merton_P), sum(Mono_P), length(Mono_P), sum(Conv_P), length(Conv_P));
disp('Risultati CALL:'); disp(Results_CALL);
disp('Risultati PUT:');  disp(Results_PUT);

%% PUNTO 2: Interpolazione quadratica (Shimko) + BS

% Ho utilizzato le opzioni Out-of-the-Money (Put per $K < S_0$ e Call per $K > S_0$)
% perché sono i contratti più liquidi. Poiché la volatilità implicita di una Call e di
% una Put con lo stesso strike deve essere identica per la Put-Call Parity, l'uso delle
% OTM garantisce una calibrazione dello Smile più robusta e meno influenzata dal rumore
% dei prezzi delle opzioni In-the-Money.

% Imposto la soglia
threshold = S0; 

% Identificazione degli indici
idx_put  = K_P < threshold;
idx_call = K_C >= threshold;

% Creo un vettore contenete gli strike OTM (anche se K_C e K_P dovrebbero
% essere uguali)
K_OTM = [K_P(idx_put); K_C(idx_call)];

% Estrazione dei Prezzi OTM
% Creo un unico vettore di prezzi "puliti"
Prices_OTM = zeros(size(K_OTM)); 
Prices_OTM(idx_put)  = Mid_P(idx_put);  % Prende le Put dove K è basso
Prices_OTM(idx_call) = Mid_C(idx_call); % Prende le Call dove K è alto

% Estrazione delle Volatilità Implicite (IV) OTM
IVM_OTM = zeros(size(K_OTM));
IVM_OTM(idx_put)  = IVM_P(idx_put);
IVM_OTM(idx_call) = IVM_C(idx_call);

% Creo una tabella per ordinare i dati OTM
Data_OTM = table(K_OTM, Prices_OTM, IVM_OTM);
Data_OTM.Properties.VariableNames = {'Strike', 'Price', 'IV'};


fprintf('\n\n\n=== PUNTO 2: Shimko e Black-Scholes ===\n\n');

K_target = 5753;
IVM_OTM_dec  = IVM_OTM / 100;           % da % a decimale
IV_tot     = IVM_OTM_dec .* sqrt(T);  % total implied vol

% Regressione quadratica (Shimko)
X_reg = [ones(size(K_OTM)), K_OTM, K_OTM.^2];
B_reg = X_reg \ IV_tot; % L'operatore backslash (\) risolve il sistema minimizzando la somma dei quadrati degli scarti (Ordinary Least Squares - OLS).
A0 = B_reg(1);
A1 = B_reg(2);
A2 = B_reg(3);
fprintf('Parametri Shimko: A0=%.6f  A1=%.8f  A2=%.12f\n', A0, A1, A2);

% Interpolazione sullo strike target
IV_total_interp = A0 + A1*K_target + A2*K_target^2;
sigma_interp    = IV_total_interp / sqrt(T);
fprintf('Total IV interpolata a K=%d: %.6f\n', K_target, IV_total_interp);
fprintf('Sigma implicita: %.4f (%.2f%%)\n', sigma_interp, sigma_interp*100);

% Grafico volatility smirk
Kgrid = linspace(min(K_OTM), max(K_OTM), 500);
IVgrid = A0 + A1*Kgrid + A2*Kgrid.^2;
figure('Name','Punto 2 - Shimko Fit');
plot(K_OTM, IV_tot, 'bo', 'MarkerSize', 5, 'DisplayName', 'Total IV osservata');
hold on;
plot(Kgrid, IVgrid, 'r-', 'LineWidth', 2, 'DisplayName', 'Fit quadratico (Shimko)');
xline(K_target, 'k--', 'DisplayName', sprintf('K target = %d', K_target));
legend('Location','best');
xlabel('Strike'); ylabel('Total Implied Volatility');
title('Shimko Quadratic Fit - EUROSTOXX50 Options');
grid on; hold off;

% Prezzo BS
[Call_BS] = blsprice(S0, K_target, r, T, sigma_interp, q);
fprintf('Prezzo Call BS (K=%d, sigma=%.4f): %.4f EUR\n\n', K_target, sigma_interp, Call_BS);


%% PUNTO 3: Monte Carlo Call Europea

fprintf('\n\n\n=== PUNTO 3: Monte Carlo ===\n\n');
K_MC    = 5740;
sigma_MC = 0.07;
Nsim    = 20000;
rng(95);  % seed per la riproducibilita'
Z  = randn(Nsim, 1);
ST = S0 * exp((r - q - 0.5*sigma_MC^2)*T + sigma_MC*sqrt(T).*Z);
Payoff      = max(ST - K_MC, 0);
Payoff_disc = exp(-r*T) * Payoff;
Price_MC = mean(Payoff_disc);
std_MC   = std(Payoff_disc); % usiamo la deviazione std campionaria corretta

% Calcolo l'intervallo di confidenza al 95%
alpha = 0.05;
z_crit = norminv(1 - alpha/2);

IC_low   = Price_MC - z_crit * std_MC / sqrt(Nsim); 
IC_high  = Price_MC + z_crit * std_MC / sqrt(Nsim);
[Price_BS_interp] = blsprice(S0, K_MC, r, T, sigma_interp, q);
[Price_BS_sig07]  = blsprice(S0, K_MC, r, T, sigma_MC, q);
fprintf('Prezzo MC:          %.4f EUR\n', Price_MC);
fprintf('IC 95%%:             [%.4f, %.4f]\n', IC_low, IC_high);
fprintf('Prezzo BS (sigma=0.07):        %.4f EUR\n', Price_BS_sig07);
fprintf('Prezzo BS (sigma interpolata): %.4f EUR\n\n', Price_BS_interp);
figure('Name','Punto 3 - Distribuzione Payoff MC');
histogram(Payoff, 100, 'Normalization', 'pdf', 'FaceColor', [0.3 0.6 0.9]);
xlabel('Payoff = max(S_T - K, 0)');
ylabel('Densità');
title(sprintf('Distribuzione payoff Call Europea MC (K=%d, \\sigma=%.2f)', K_MC, sigma_MC));
grid on;

%% PUNTO 4: VSTOXX model-free (VIX methodology)

fprintf('\n\n\n=== PUNTO 4: VSTOXX Model-Free ===\n\n');

% Selezione opzioni OTM (!!!! Calcoliamo le OTM rispetto al FORWARD)
Forw = S0 * exp((r - q) * T);
K_P_OTM   = K_P(K_P < Forw);
Mid_P_OTM = Mid_P(K_P < Forw);
K_C_OTM   = K_C(K_C > Forw);
Mid_C_OTM = Mid_C(K_C > Forw);
% ATM: se uno strike coincide esattamente con F, usa Put per convenzione
StrikeOTM = [K_P_OTM; K_C_OTM];
PriceOTM  = [Mid_P_OTM; Mid_C_OTM];
[StrikeOTM, idx] = sort(StrikeOTM);
PriceOTM = PriceOTM(idx);
% deltaK corretto (formula VIX ufficiale CBOE)
n = length(StrikeOTM);
deltaK = zeros(n, 1);
deltaK(1)     = StrikeOTM(2) - StrikeOTM(1);
deltaK(end)   = StrikeOTM(end) - StrikeOTM(end-1);
deltaK(2:end-1) = (StrikeOTM(3:end) - StrikeOTM(1:end-2)) / 2;
K0   = max(StrikeOTM(StrikeOTM <= Forw));
VSTOXX_model = sqrt( (2*exp(r*T)/T) * sum((deltaK ./ StrikeOTM.^2) .* PriceOTM) ...
               - (1/T) * (Forw/K0 - 1)^2 ) * 100;

% Valore quotato da Bloomberg (VSTOXX al 30/03/2026)
VSTOXX_quoted = 34.3125;
fprintf('VSTOXX model-free: %.4f%%\n', VSTOXX_model);
fprintf('VSTOXX quotato (Bloomberg): %.4f%%\n', VSTOXX_quoted);
fprintf('Differenza: %.4f%%\n\n', abs(VSTOXX_model - VSTOXX_quoted));

%% PUNTO 5: Scatter SX5E vs VSTOXX + Vasicek AR(1)

fprintf('\n\n\n=== PUNTO 5: Vasicek AR(1) ===\n\n');

% Lettura serie storiche
SX5E_tab    = readtable("EUSTX.xlsx", "Sheet", "EUROSTOX", ...
    "VariableNamingRule", "preserve", "Range", "A6:B10000");
VSTOXX_tab  = readtable("EUSTX.xlsx", "Sheet", "VSTOXX", ...
    "VariableNamingRule", "preserve", "Range", "A6:B10000");

% Allineamento delle date
[~, ia, ib] = intersect(SX5E_tab{:,1}, VSTOXX_tab{:,1});
SX5E      = SX5E_tab{ia, 2};
VSTOXX_ts = VSTOXX_tab{ib, 2};

% Converti in double e rimuovi NaN
SX5E      = double(SX5E);
VSTOXX_ts = double(VSTOXX_ts);
valid = ~isnan(SX5E) & ~isnan(VSTOXX_ts);
SX5E      = SX5E(valid);
VSTOXX_ts = VSTOXX_ts(valid);

% Log returns
r_SX5E   = diff(log(SX5E));
r_VSTOXX = diff(log(VSTOXX_ts));

% Scatterplot + leverage effect
corr_lev = corr(r_SX5E, r_VSTOXX);
fprintf('Correlazione SX5E vs VSTOXX: %.4f\n', corr_lev);

if corr_lev < 0
    fprintf('Leverage effect PRESENTE (correlazione negativa)\n\n');
else
    fprintf('Leverage effect NON evidente\n\n');
end

figure('Name','Punto 5 - Scatter SX5E vs VSTOXX');
scatter(r_SX5E, r_VSTOXX, 15, '.', 'MarkerEdgeColor', [0.2 0.4 0.8]);
hold on;
X_sc = [ones(length(r_SX5E),1), r_SX5E];
b_sc = X_sc \ r_VSTOXX;
xline_v = linspace(min(r_SX5E), max(r_SX5E), 100)';
plot(xline_v, b_sc(1) + b_sc(2)*xline_v, 'r-', 'LineWidth', 2);
xlabel('Rendimenti EUROSTOXX50'); ylabel('Rendimenti VSTOXX');
title(sprintf('Scatterplot rendimenti | corr = %.4f', corr_lev));
legend('Dati','Regressione OLS'); grid on; hold off;

% --- VASICEK su EUROSTOXX50 ---
Y_e = r_SX5E(2:end);
X_e = r_SX5E(1:end-1);
Xmat_e = [X_e, ones(length(X_e),1)];
B_e    = Xmat_e \ Y_e;
phi_e    = B_e(1);
lambda_e = 1 - phi_e;
mu_e     = B_e(2) / (1 - phi_e);
eps_e    = Y_e - Xmat_e * B_e;
sigma_e  = std(eps_e);
figure('Name','Punto 5 - Vasicek EUROSTOXX50');
plot(X_e, Y_e, '.', 'MarkerSize', 4, 'Color', [0.2 0.5 0.8]);
lsline;
xlabel('r_t'); ylabel('r_{t+1}');
title('Vasicek AR(1) – EUROSTOXX50'); grid on;

% --- VASICEK su VSTOXX ---
Y_v = r_VSTOXX(2:end);
X_v = r_VSTOXX(1:end-1);
Xmat_v = [X_v, ones(length(X_v),1)];
B_v    = Xmat_v \ Y_v;
phi_v    = B_v(1);
lambda_v = 1 - phi_v;
mu_v     = B_v(2) / (1 - phi_v);
eps_v    = Y_v - Xmat_v * B_v;
sigma_v  = std(eps_v);
figure('Name','Punto 5 - Vasicek VSTOXX');
plot(X_v, Y_v, '.', 'MarkerSize', 4, 'Color', [0.8 0.3 0.2]);
lsline;
xlabel('r_t'); ylabel('r_{t+1}');
title('Vasicek AR(1) – VSTOXX'); grid on;

% Tabella risultati Vasicek
Asset          = {'EUROSTOXX50'; 'VSTOXX'};
phi            = [phi_e;    phi_v];
lambda         = [lambda_e; lambda_v];
mu_lr          = [mu_e;     mu_v];
sigma_res      = [sigma_e;  sigma_v];
Results_Vasicek = table(Asset, phi, lambda, mu_lr, sigma_res, ...
    'VariableNames', {'Asset','phi_AR1','lambda_MR','mu_LongRun','sigma_Residual'});

fprintf('Vasicek EUROSTOXX50: phi=%.4f  lambda=%.4f  mu=%.6f  sigma=%.6f\n', phi_e, lambda_e, mu_e, sigma_e);
fprintf('Vasicek VSTOXX:      phi=%.4f  lambda=%.4f  mu=%.6f  sigma=%.6f\n\n', phi_v, lambda_v, mu_v, sigma_v);
disp(Results_Vasicek);

%% PUNTO 6: Normale e Variance Gamma su Euribor 6M

fprintf('\n\n\n=== PUNTO 6: Normale e Variance Gamma su Euribor 6m ===\n\n');

% Lettura Euribor 6M
EuriborTab = readtable("EURIB.xlsx", "Sheet", "EURIB6M", ...
    "VariableNamingRule", "preserve");
tassi_eur  = EuriborTab.Var2(7:end) / 100;
ReturnEuribor = diff(log(tassi_eur)); % (dato che i tassi usono tutti positivi usiamo i log-returns)

% Rimuovi Inf/NaN (possibili se tasso = 0)
ReturnEuribor = ReturnEuribor(isfinite(ReturnEuribor));
fprintf('N osservazioni Euribor log-returns: %d\n', length(ReturnEuribor));

% --- Stima Normale ---
[mu_norm, sigma_norm] = normfit(ReturnEuribor);
fprintf('Normale: mu=%.6f  sigma=%.6f\n', mu_norm, sigma_norm);

% --- Stima VG tramite MLE ---
p0 = [0.004, -0.05, 0.01, 1.2];
par_VG = fmincon(@(x) -MLEvg(ReturnEuribor, x), p0, [], [], [], [], [-10, -10, 0, 0]);
fprintf('VG parametri: mu=%.6f  theta=%.6f  sigma=%.6f  nu=%.6f\n\n', ...
    par_VG(1), par_VG(2), par_VG(3), par_VG(4));

% --- Grafico ---
x_grid = -0.05:0.001:0.05;
pdf_norm = normpdf(x_grid, mu_norm, sigma_norm);
pdf_VG   = densita_VG(x_grid, par_VG(1), par_VG(2), par_VG(3), par_VG(4));
figure('Name','Punto 6 - VG vs Normale');
histogram(ReturnEuribor, 40, 'Normalization', 'pdf', 'FaceColor', [0.8 0.85 1], 'EdgeColor', 'none');
hold on;
plot(x_grid, pdf_VG,   'r-',  'LineWidth', 2, 'DisplayName', 'Variance Gamma');
plot(x_grid, pdf_norm, 'g--', 'LineWidth', 2, 'DisplayName', 'Normale');
legend('Empirico Euribor 6M', 'Variance Gamma', 'Normale', 'Location', 'best');
title('Distribuzione rendimenti Euribor 6M');
xlabel('Log-returns'); ylabel('Densità'); grid on; hold off;

% QQ-plot
figure('Name','Punto 6 - QQ plot');
qqplot(ReturnEuribor);
title('QQ-plot rendimenti Euribor 6M'); grid on;

% Test statistici
h_ks = kstest((ReturnEuribor - mu_norm) / sigma_norm);
h_jb = jbtest(ReturnEuribor);
fprintf('KS test (H0=normale): %d (0=non rifiuto, 1=rifiuto)\n', h_ks);
fprintf('JB test (H0=normale): %d\n\n', h_jb);

%% PUNTO 7: Bootstrap OIS -> Zero rate e Discount curve

fprintf('\n\n\n=== PUNTO 7: Curva OIS Bootstrap ===\n\n');

OIS_tab = readtable("CURVE_OIS_EUR3M_CDS.xlsx", "Sheet", "EUR OIS", ...
    "VariableNamingRule", "preserve");
R_ois = (OIS_tab.("Final Bid Rate") + OIS_tab.("Final Ask Rate")) / 2;
R_ois = R_ois / 100;

% Converti scadenze in anni (ACT/360 per OIS)
T_ois = zeros(height(OIS_tab), 1);
for i = 1:height(OIS_tab)
    switch OIS_tab.Unit{i}
        case 'WK'
            T_ois(i) = OIS_tab.Term(i) * 7 / 360;
        case 'MO'
            T_ois(i) = OIS_tab.Term(i) * 30 / 360;
        case 'YR'
            T_ois(i) = OIS_tab.Term(i);
    end
end

% Bootstrap discount factors
n_ois  = length(T_ois);
DF_ois = zeros(n_ois, 1);
for i = 1:n_ois
    delta     = diff([0; T_ois(1:i)]);
    fixed_leg = sum(DF_ois(1:i-1) .* delta(1:i-1));
    DF_ois(i) = (1 - R_ois(i) * fixed_leg) / (1 + R_ois(i) * delta(i));
end

% Zero rates
z_ois = -log(DF_ois) ./ T_ois;
OIS_Curve = table(T_ois, z_ois*100, DF_ois, ...
    'VariableNames', {'Maturity_anni','ZeroRate_pct','DiscountFactor'});
fprintf('Curva OIS bootstrappata (%d punti):\n', n_ois);
disp(OIS_Curve(:,:));

% Grafici
figure('Name','Punto 7 - Zero Rate Curve');
plot(T_ois, z_ois*100, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Maturity (anni)'); ylabel('Zero Rate (%)');
title('EUR OIS Zero Rate Curve'); grid on;

figure('Name','Punto 7 - Discount Curve');
plot(T_ois, DF_ois, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Maturity (anni)'); ylabel('Discount Factor');
title('EUR OIS Discount Curve'); grid on;

%% PUNTO 8: Bond callable equity-linked con rischio credito
% Emittente: Credit Agricole (ACAFP)

fprintf('\n\n\n=== PUNTO 8: Callable Bond Credit Agricole ===\n\n');

% Lettura CDS
CDS_tab = readtable("CURVE_OIS_EUR3M_CDS.xlsx", "Sheet", "CDS", ...
    "VariableNamingRule", "preserve");
Settle = datenum('30-Mar-2026');

% Parametri bond
N_bond = 100;
c_bond = 0.04;
Tbond  = 4;
freq   = 2;
ti     = (1/freq : 1/freq : Tbond)'; % vettore scadenza cedole
nCpn   = length(ti);

% Parametri simulazione
dt     = 1/252;
Nsim   = 20000;
Tsim   = 5;
nSteps = round(Tsim / dt);

% Volatilita' EUROSTOXX50 annualizzata
% Calcolo la volatilità storica log-normale annualizzata dell'EUROSTOXX50 per il Geometric Brownian Motion (GBM).
ret_eq   = diff(log(SX5E));
sigma_eq = std(ret_eq) * sqrt(252);
fprintf('Sigma equity (annualizzata): %.4f\n', sigma_eq);

% Discount factor OIS interpolato
DF_rf = @(t) interp1(T_ois, DF_ois, t, 'pchip', 'extrap'); % pchip è shape-preserving, garantisce che la curva sia continua e derivabile (liscia), ma evita le oscillazioni (overshooting)
DF_i  = DF_rf(ti);

% --- Bootstrap probabilita' di default (Credit Agricole) ---
% Converti scadenze CDS in datenum
CDSTenors = CDS_tab.DATE;
CDSDates  = zeros(length(CDSTenors), 1);
for i = 1:length(CDSTenors)
    tok = CDSTenors{i};
    if endsWith(tok, 'M')
        nM = str2double(extractBefore(tok, 'M'));
        CDSDates(i) = datemnth(Settle, nM);
    elseif endsWith(tok, 'Y')
        nY = str2double(extractBefore(tok, 'Y'));
        CDSDates(i) = datemnth(Settle, 12*nY);
    end
end
% Il risultato finale di datemnth è un numero seriale di data (MATLAB serial date number)

% CDS spreads in basis points -> usiamo CMAN mid
CDSSpreads = CDS_tab.("CMAN (mid)");

% Curve OIS per cdsbootstrap
Date_ois_num = Settle + round(T_ois * 365);
ZeroData     = [Date_ois_num, z_ois];
probDates = Settle + ti * 365;
probData  = cdsbootstrap(ZeroData, [CDSDates, CDSSpreads], Settle, ...
    'probDates', probDates);
PD_i = probData(:, 2);   % Probabilita' di default cumulata
S_i  = 1 - PD_i;         % Survival probability
DF_credit_i = DF_i .* S_i;
fprintf('Survival probability e Risky Discount Factor alle date cedola:\n');

for i = 1:nCpn
    fprintf('  t=%.1f: DF_rf=%.4f  S=%.4f  DF_credit=%.4f\n', ti(i), DF_i(i), S_i(i), DF_credit_i(i));
end

% --- Simulazione GBM risk-neutral EUROSTOXX50 ---
rng(95);
S_sim    = zeros(nSteps+1, Nsim);
S_sim(1,:) = S0;
mu_rn    = r - q;

for t = 2:nSteps+1
    Z_t = randn(1, Nsim);
    S_sim(t,:) = S_sim(t-1,:) .* exp((mu_rn - 0.5*sigma_eq^2)*dt + sigma_eq*sqrt(dt).*Z_t);
end

% Estrai valori alle date cedola
idx_cedola = 1 + round(ti / dt); % Questa riga traduce il tempo espresso in anni nell'indice di riga corrispondente della matrice.
idx_cedola = min(idx_cedola, nSteps+1); % Serve a evitare errori di "Index out of bounds".
S_ti = S_sim(idx_cedola, :);   % nCpn x Nsim

% =========================================== 
% APPROCCIO 1: MEDIA dei sottostanti simulati 
% =========================================== 

Sbar_i    = mean(S_ti, 2); % media orizzontale delle simulazioni
ratio_bar = Sbar_i / S0; 
coupon_bar = ratio_bar > 0.95; % condizione per la cedola
call_bar   = ratio_bar > 1.15; % condizione per il rimborso anticipato
idxCall_bar = find(call_bar, 1, 'first');

if isempty(idxCall_bar)
    Price_mean = sum(DF_credit_i .* (N_bond * c_bond * coupon_bar)) ...
               + DF_credit_i(end) * N_bond;
else
    Price_mean = sum(DF_credit_i(1:idxCall_bar) .* (N_bond * c_bond * coupon_bar(1:idxCall_bar))) ...
               + DF_credit_i(idxCall_bar) * N_bond;
end

fprintf('\n--- Approccio 1: Media dei sottostanti ---\n');
fprintf('Ratio medio per data cedola:\n');

for i = 1:nCpn
    fprintf('  t=%.1f: Sbar=%.2f  ratio=%.4f  coupon=%d  call=%d\n', ...
        ti(i), Sbar_i(i), ratio_bar(i), coupon_bar(i), call_bar(i));
end

fprintf('Prezzo bond (media): %.4f EUR\n', Price_mean);

% ===================================================
% APPROCCIO 2: PATHWISE (traiettoria per traiettoria)
% ===================================================

PVj = zeros(Nsim, 1);

for j = 1:Nsim
    ratio_j  = S_ti(:, j) / S0;
    coupon_j = ratio_j > 0.95;
    call_j   = ratio_j > 1.15;
    idxCall_j = find(call_j, 1, 'first');
    if isempty(idxCall_j)
        PVj(j) = sum(DF_credit_i .* (N_bond * c_bond * coupon_j)) ...
               + DF_credit_i(end) * N_bond;
    else
        PVj(j) = sum(DF_credit_i(1:idxCall_j) .* (N_bond * c_bond * coupon_j(1:idxCall_j))) ...
               + DF_credit_i(idxCall_j) * N_bond;
    end
end

Price_MC_bond = mean(PVj);
CI95_bond     = Price_MC_bond + [-1, 1] * 1.96 * std(PVj) / sqrt(Nsim); % intervallo di confidenza
fprintf('\n--- Approccio 2: Pathwise ---\n');
fprintf('Prezzo bond (pathwise MC): %.4f EUR\n', Price_MC_bond);
fprintf('IC 95%%: [%.4f, %.4f]\n\n', CI95_bond(1), CI95_bond(2));

% Istogramma prezzi pathwise
figure('Name','Punto 8 - Distribuzione prezzi bond');
histogram(PVj, 60, 'Normalization', 'pdf', 'FaceColor', [0.3 0.7 0.4]);
xline(Price_MC_bond, 'r--', 'LineWidth', 2, 'DisplayName', sprintf('Media = %.2f', Price_MC_bond));
xlabel('Prezzo bond'); ylabel('Densità');
title('Distribuzione prezzi bond callable equity-linked (Credit Agricole)');
legend; grid on;

fprintf('\n\n\n=== FINE ASSIGNMENT ===\n');

# Advanced Derivatives Assignment - a.a. 2025/2026
**Università degli Studi di Milano-Bicocca** **Corso di Laurea Magistrale in Economia e Finanza**

## Autori
* Cristian Losi
* Marco Arienti
* Matteo Ciotta

## Panoramica del Progetto
Questo repository ospita il codice MATLAB e l'analisi quantitativa sviluppata per l'assignment di Advanced Derivatives. Il progetto si focalizza sulla modellizzazione, calibrazione e pricing di strumenti derivati complessi, utilizzando dati reali estratti dal terminale **Bloomberg** con data di riferimento 30/03/2026.

## Contenuti Tecnici

### 1. Analisi delle Opzioni e Volatilità Implicita
* **Verifica di Arbitraggio**: Test di consistenza dei prezzi di mercato tramite i vincoli di Merton (Lower/Upper Bound), monotonicità e convessità.
* **Volatility Smile**: Calibrazione della superficie di volatilità per l'indice EUROSTOXX50 tramite l'interpolazione quadratica di **Shimko** nello spazio della Total Implied Volatility.
* **Pricing**: Confronto tra il modello analitico di Black & Scholes e la simulazione **Monte Carlo** per opzioni europee.

### 2. Indici di Volatilità e Dinamiche di Mercato
* **VSTOXX Replication**: Implementazione dell'algoritmo model-free per la replica dell'indice di volatilità europeo, con confronto rispetto ai dati ufficiali Bloomberg.
* **Leverage Effect**: Analisi della correlazione negativa tra rendimenti azionari e volatilità implicita.
* **Modello di Vasicek**: Stima dei parametri di Mean Reversion ($\lambda$, $\mu$, $\sigma$) per le serie storiche tramite discretizzazione di Eulero.

### 3. Struttura a Termine e Distribuzioni Empiriche
* **Bootstrapping**: Costruzione della **Discount Curve** e della **Zero Rate Curve** (fino a 50 anni) utilizzando tassi EUR OIS.
* **Euribor 6m Analysis**: Analisi della distribuzione dei rendimenti del tasso interbancario, confrontando il modello Gaussiano con la distribuzione **Variance Gamma (VG)** stimata via Maximum Likelihood (MLE).

### 4. Credit Risk e Prodotti Strutturati
* **Probability of Default**: Estrazione delle probabilità di sopravvivenza di Credit Agricole a partire dalla curva dei CDS spread.
* **Pricing Equity-Linked Bond**: Valutazione di un **Callable Bond** con cedola condizionale. L'analisi mette in luce la discrepanza tra l'approccio deterministico (basato sulla media) e la corretta valutazione Monte Carlo "path-dependent".

## Struttura della Repository
* `/src`: Script e funzioni MATLAB (`.m`).
* `/data`: Dataset finanziari in formato Excel (Eurostoxx50, VSTOXX, Curve OIS/CDS).
* `/docs`: Report integrale in PDF con analisi dettagliata e commenti ai risultati.

## Requisiti
* MATLAB
* Financial Toolbox
* Optimization Toolbox

function y = densita_VG(x, m0, m, sigma, a)
    y = zeros(1, length(x));
    for i = 1:length(x)
        a_0  = exp((x(i) - m0) * m / sigma^2);
        Z    = sqrt(2*sigma^2 + m^2) * abs(x(i) - m0) / sigma^2;
        k    = besselk(a - 0.5, Z);
        d    = sqrt(2) * (abs(x(i) - m0) / sqrt(m^2 + 2*sigma^2))^(a - 0.5);
        y(i) = d * a_0 * k / (gamma(a) * sigma * sqrt(pi));
    end
end


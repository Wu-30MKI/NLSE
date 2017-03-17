% MLLsimple.m
% simple model of mode locked laser
% written by Saiyu Luo
clear;
clc;

global Ts;			% sampling period
global Fcar;		% carrier frequency (optical frequency)
c_const = 3e8;		% speed of light

lamda = 640e-9;	% m
Fcar = c_const/lamda;

Ts = 0.1e-12;		% 0.1 ps
N = 1024;			% number of samples in a block. Tblk = N * Ts = 102.4 ps

% Amplifier parameters:
  GssdB = 20;		% (dB)
  PoutsatdB = 10;	% (dBm)
  % NF = 8;			% (dB)

% filter bandwidth
  lamda3dB = 0.2e-9;	% m
  % f3dB = lamda3dB*(1e11/0.8e-9);  % for lamda = 1550e-9
  f3dB = lamda3dB*c_const/lamda^2;  % for arbitrary lamda

% filter order
    n=1;
% index of the amount of gain line splitting
    shift = 6

% modulator parameters
  alpha = -0.07;
  epsilon = 40;		% (dB) extinction ratio
  
% modulation parameters
  m = 0.5;			% modulation index, by increasing it, the spectra is broadened, and the pulse is shortened.
                    % it can be considered as a magnification factor of fm
  fm = 10e9;		% modulation frequency, 
                    % by increasing it, the shape will be narrowed
                    % when it is small than f3dB, when increasing it, the spectra is broadened and the pulse is shortened.
                    % while it exceed f3dB, it will only modulate single frequency, pulse will not form.

% Loss
  loss = 10;			% dB
  atten = 1/10^(loss/20);

% generate an initial block of signal Ein
% Generate an N-by-1 matrix of complex white Gaussian noise having power -40 dBW. 
Ein = wgn(N,1,-40,'complex');

Eout = Ein;
Eo = Ein;
N_pass = 500;
% N_pass = 50;
for ii = 1:N_pass
    fprintf('----------------------------\n', ii);
    fprintf('pass %d begin\n', ii);
	[Eo,G] = AmpSimpNonoise(Eo,GssdB,PoutsatdB); % no noise
	Eo = fft(Eo);
	% Eo = filter_gaus(Eo,f3dB,n);  % multiply by a gaussian filter in the frequency domain, which is equivalent to convolve by a gaussian filter in the time domain.
	Eo = filter_gaus_stark_shift(Eo,f3dB,shift,n);
	Eo = ifft(Eo);
	% Eo = modInt(Eo(1:N),alpha,epsilon,m,fm,0.5);
	Eo = modInt_theory(Eo(1:N),m,fm);   % Eo(1:N) is a abbreviation for Eo(1:N,1), which represents the 1'th row to the N'th row, 1th column.
                                        % A(a:b,c:d) represents the overlay of a'th row to b'th row and c'th column to d'th column.
                                        % multiply by a gaussian-like filter in the time domain
	Eo = Eo*atten;
	if mod(ii,N_pass/50)==0 % display part of the N_pass
		Eout = [Eout, Eo];  % add noise
	end
    fprintf('pass %d end\n', ii);
    fprintf('----------------------------\n', ii);
end
Eout = Eout/atten;
close all

% -------------- Display the results ---------
% mesh (abs(Eout'),'edgecolor','black','meshstyle','row', 'facecolor','none');
Iout = Eout.*conj(Eout);
mesh (Iout','meshstyle','row','facecolor','none');
axis tight;
% set(gca,'XTick',tt_mark);
% set(gca,'XTickLabel',tt_tick);
% set(gca,'XDir','reverse');
xlabel('T (0.1ps)');
% set(gca,'YTick',yy_mark);
% set(gca,'YTickLabel',yy_tick);
ylabel('Pass number');
zlabel('intensity (W)');

N1 = size(Eout,2);
% N1 = 5;
% dPhi = angle(Eout(2:N,N1)) - angle(Eout(1:N-1,N1));
% figure (2);
% plot(dPhi);
% plot(fftshift(dPhi));

% return the Full Width at Half Maximum of the pulse x
% Tp = fwhm(Iout(:,N1))*Ts;
% pulse_alpha = 2*log(2)/(Tp^2);
% pulse_beta = (dPhi(N/2+100) - dPhi(N/2-100))/200/Ts/Ts;
%  chirp = pulse_beta/pulse_alpha

Kmag = 8;   % this factor is proportional to the refinement (interval between points) of the transformed frequency data;
            % the total frequency range is determined by the total time range and will not be changed. By changing Kmag, we are changing the number of points in the frequency domain, thus the refinement.
Nplot = 100;    % plotted frequency points, it determines the plotted frequency range, not the refinement. 
                % this factor is related to the index of the frequency points
Eoutfreq = fft(Eout(:,N1),N*Kmag);  % take the last pulse and transform it to frequency domain
Ioutfreq = Eoutfreq.*conj(Eoutfreq)/(N*Kmag)^2;

figure(2);
ind = (- Nplot/2 : Nplot/2)';   % index
delta_freq = 1/(Ts*N*Kmag); % it determines the refinement in the frequency domain.
% freq = ind/Ts/N/Kmag;
freq = ind*delta_freq;
ind = mod((ind + N*Kmag),N*Kmag)+1; % this step just turn index into positive ones, and complete the fftshift step;
                                    % if not pluse 1, index will contain 0, but the indices of MATLAB must be real positive integers.
Ioutfreq = Ioutfreq/max(Ioutfreq);  % normalization                                    
plot(freq,Ioutfreq(ind));

n = 2*n;

shift = shift * Kmag    % freq is actually be refined, so we should tune shift fitst by multiplying with Kmag
% Tfil = exp(-log(2)*(2/f3dB*freq).^n);	% n order gaussian filter VPI
%% Tfil = (exp(-log(2)*(2/f3dB*(freq-shift*delta_freq)).^n)+exp(-log(2)*(2/f3dB*(freq+shift*delta_freq)).^n))/2;	% n order gaussian filter VPI
Tfil = (exp(-log(2)*(2/f3dB*(freq-shift*delta_freq)).^n)+exp(-log(2)*(2/f3dB*(freq+shift*delta_freq)).^n))/2;
Tfil = Tfil/max(Tfil);  % normalization
hold on
plot(freq,Tfil,'r');

% plot the gaussian fit curve
% gaussFit(Iout(:,N1));

pulseBW = fwhm(Ioutfreq(ind))/Ts/N/Kmag
Tp = fwhm(Iout(:,N1))*Ts*1e12   % ps
TBP = pulseBW*Tp

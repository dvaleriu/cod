function [Mid,Did,Dva] = ISLAB_5C(A,B,C,nk,N,sigma,lambda) 

% ISLAB_5C   Module that estimates an ARX model by using LSM or MVI. 
%
% Inputs:	A      # true coefficients of AR part 
%                        ([1 -1.5 0.7], by default)
%        	B      # true coefficients of X part 
%                        ([1 0.5], by default)
%        	C      # true coefficients of MA part (noise filter)
%                        ([1 -1 0.2], by default)
%               nk     # intrinsic delay of process (1, by default)
%               N      # simulation period (250, by default)
%               sigma  # standard deviation of PRB input 
%                        (1, by default); 
%                        if null, ARMA or AR processes are considered
%               lambda # standard deviation of white noise 
%                        (1, by default)
%
% Outputs:      Mid    # IDMODEL object representing the 
%                        estimated model
%               Did    # IDDATA object representing the 
%                        data generated for identification
%               Dva    # IDDATA object representing the 
%                        data generated for validation

%
% BEGIN
% 

%MENIUL PENTRU SELECTIA METODEI DE ESTIMARE
disp('Alegeti metoda de estimare:');
disp(' - 1 : Metoda Celor Mai Mici Patrate');
disp(' - 2 : MVI - nefiltrat');
disp(' - 3 : MVI - partial filtrat dreapta');
disp(' - 4 : MVI - partial filtrat stanga');
disp(' - 5 : MVI - total filtrat');
Flag = input('Introduceti numarul metodei: ', 's');

global FIG ;			% Figure number handler 
FIG=1;                           % (to be set before running the routine). 

%
% Constants
% ~~~~~~~~~
alpha = 3 ;			% Weighting factor of 
				% confidence disks radius. 
pf = 0; 			% Plot flag: 0=no, 1=yes. 
Na = 8 ; 			% Maximum index of AR part. 
Nb = 8 ;			% Maximum index of X part. 
Ts = 1 ; 			% Sampling period. 
% 
% Faults preventing
% ~~~~~~~~~~~~~~~~~
if (nargin < 7)
   lambda = 1 ;
end 
if (isempty(lambda))
   lambda = 1 ;
end  
lambda = abs(lambda(1)) ; 
if (~lambda)
   lambda = 1 ; 
end 
if (nargin < 6)
   sigma = 1 ;
end 
if (isempty(sigma))
   sigma = 1 ;
end 
sigma = abs(sigma(1)) ; 
if (nargin < 5)
   N = 250 ;
end
if (isempty(N))
   N = 250 ;
end 
N = abs(fix(N(1))) ; 
if (~N)
   N = 250 ;
end 
if (nargin < 4)
   nk = 1 ;
end 
if (isempty(nk))
   nk = 1 ;
end 
nk = abs(fix(nk(1))) ; 
if (~nk)
   nk = 1 ;
end 
if (nargin < 3)
   C = [1 -1 0.2] ;
end 
if (isempty(C))
   C = [1 -1 0.2] ;
end 
if (nargin < 2)
   B = [1 0.5] ;
end 
if (isempty(B))
   B = [1 0.5] ;
end 
if (nargin < 1)
   A = [1 -1.5 0.7] ;
end
if (isempty(A))
   A = [1 -1.5 0.7] ;
end
A = roots(A) ; 
A(abs(A)>=1) = 1./A(abs(A)>=1) ; 	% Correct the stability. 
A = poly(A) ; 
% 
% Generating the identification data 
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Did = gendata(A,B,C,nk,N,sigma,lambda) ; 
% 
% Generating the validation data
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Dva = gendata(A,B,C,nk,N,sigma,lambda) ; 
% 
% Estimating all models via LSM
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Na = Na+1 ;
Nb = Nb+1 ;
M = cell(Na,Nb) ; 			% Cell array of all models. 
Lambda = 1000*lambda*ones(Na,Nb) ; 	% Matrix of noise variances. 
Yid = cell(Na,Nb) ; 			% Cell array of simulated 
                                        % outputs when using 
                                        % the identification data. 
Yva = cell(Na,Nb) ; 			% Cell array of simulated 
                                        % outputs when using 
                                        % the validation data. 
PEid = cell(Na,Nb) ; 			% Cell array of prediction 
                                        % errors on identification data. 
PEva = cell(Na,Nb) ; 			% Cell array of prediction 
                                        % errors on validation data.
Eid = zeros(Na,Nb) ; 			% Matrix of fitness values 
                                        % evaluated on identification 
                                        % data. 
Eva = zeros(Na,Nb) ; 			% Matrix of fitness values 
                                        % evaluated on validation 
                                        % data. 
yNid = Did.y-mean(Did.y) ;		% Centered output identification 
                                        % data. 
yNva = Dva.y-mean(Dva.y) ;		% Centered output validation 
                                        % data. 
Viid = zeros(Na,Nb) ; 			% Validation index matrix 
                                        % (identification data). 
Viva = zeros(Na,Nb) ; 			% Validation index matrix 
                                        % (validation data).
if (~pf)
   war_err(['    * Models estimation started. ' ... 
                  'This may take few moments. Please wait...']) ; 
end 
for na=1:Na
   for nb=1:Nb
      if ((na>1) || (nb>1)) 
         % Model estimation.
          Mid = iv_std(Did, na, nb, nk, N, Flag);
         M{na,nb} = Mid ; 		% Save model & variance. 
         Lambda(na,nb) = Mid.NoiseVariance ; 
         PEid{na,nb} = resid(Mid,Did) ;	% Save the prediction errors. 
         PEva{na,nb} = resid(Mid,Dva) ; 
         ys = sim(Mid,Did) ;		% Save simulated outputs 
         Yid{na,nb} = ys.y ;	        % (noise free). 
         ys = sim(Mid,Dva) ; 
         Yva{na,nb} = ys.y ; 
					% Save fitness values. 
         Eid(na,nb) = 100*(1-norm(PEid{na,nb}.y)/norm(yNid)) ; 
         Eva(na,nb) = 100*(1-norm(PEva{na,nb}.y)/norm(yNva)) ; 
                    % Save validation indices.
         %IN FUNCTIE DE CAZ SE APELEAZA valid_LS SAU valid_IV DUPA CAZ
         if(strcmp(Flag,'1')) % MCMMP
            Viid(na,nb) = valid_LS(Mid,Did) ; 
            Viva(na,nb) = valid_LS(Mid,Dva) ;
         else                   % MVI
            Viid(na,nb) = valid_IV(Mid,Did) ; 
            Viva(na,nb) = valid_IV(Mid,Dva) ;
         end
         
         if(pf)				% Show model performances
            figure(FIG),clf ;
               fig_look(FIG,1.5) ; 
               subplot(321)
                  plot(1:N,Did.y,'-b',1:N,Yid{na,nb},'-r') ; 
                  title('Identification data') ; 
                  ylabel('Outputs') ; 
                  ys = [min(min(Did.y),min(Yid{na,nb})) ... 
                        max(max(Did.y),max(Yid{na,nb}))] ; 
                  dy = ys(2)-ys(1) ; 
                  axis([0 N+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
                  text(1.22*N,ys(2)+0.45*dy, ... 
                       ['na = ' int2str(na-1) ... 
                        ' | nb = ' int2str(nb-1)]) ; 
                  text(N/2,ys(2)+0.05*dy, ... 
                       ['Fitness E_N = '  ...
                        sprintf('%g',Eid(na,nb)) ' %']) ;
               subplot(322)
                  plot(1:N,Dva.y,'-b',1:N,Yva{na,nb},'-r') ; 
                  title('Validation data') ; 
                  ylabel('Outputs') ; 
                  ys = [min(min(Dva.y),min(Yva{na,nb})) ... 
                        max(max(Dva.y),max(Yva{na,nb}))] ; 
                  dy = ys(2)-ys(1) ; 
                  axis([0 N+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
                  text(N/2,ys(2)+0.05*dy, ... 
                       ['Fitness E_N = '  ...
                        sprintf('%g',Eva(na,nb)) ' %']) ;
                  set(FIG,'DefaultTextHorizontalAlignment','left') ; 
                  legend('y','ym') ; 
                  set(FIG,'DefaultTextHorizontalAlignment','center') ; 
               subplot(323)
                  plot(1:N,PEid{na,nb}.y,'-m') ; 
                  ylabel('Prediction error') ; 
                  ys = [min(PEid{na,nb}.y) ... 
                        max(PEid{na,nb}.y)] ; 
                  dy = ys(2)-ys(1) ; 
                  axis([0 N+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
                  text(N/2,ys(2)+0.07*dy, ... 
                       ['\lambda^2 = '  ...
                        sprintf('%g',std(PEid{na,nb}.y,1)^2)]) ;
               subplot(324)
                  plot(1:N,PEva{na,nb}.y,'-m') ; 
                  ylabel('Prediction error') ; 
                  ys = [min(PEva{na,nb}.y) ... 
                        max(PEva{na,nb}.y)] ; 
                  dy = ys(2)-ys(1) ; 
                  axis([0 N+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
                  text(N/2,ys(2)+0.07*dy, ... 
                       ['\lambda^2 = '  ...
                        sprintf('%g',std(PEva{na,nb}.y,1)^2)]) ; 
               subplot(325)
                  set(FIG,'DefaultLineLineWidth',0.5) ; 
                  set(FIG,'DefaultLineMarkerSize',2) ; 
                  [r,K] = xcov(PEid{na,nb}.y,'unbiased') ; 
                  r = r(K>=0) ; 
                  K = ceil(length(r)/2) ; 
                  r = r(1:K) ; 
                  stem(1:K,r,'-g','filled') ; 
                  xlabel('Normalized time') ; 
                  ylabel('Auto-covariance') ; 
                  ys = [min(r) max(r)] ; 
                  dy = ys(2)-ys(1) ; 
                  axis([0 K+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
                  text(K/2,ys(2)+0.05*dy, ... 
                       ['Validation index = '  ...
                        num2str(Viid(na,nb))]) ; 
               subplot(326)
                  [r,K] = xcov(PEva{na,nb}.y,'unbiased') ; 
                  r = r(K>=0) ; 
                  K = ceil(length(r)/2) ; 
                  r = r(1:K) ; 
                  stem(1:K,r,'-g','filled') ; 
                  xlabel('Normalized time') ; 
                  ylabel('Auto-covariance') ; 
                  ys = [min(r) max(r)] ; 
                  dy = ys(2)-ys(1) ; 
                  axis([0 K+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
                  text(K/2,ys(2)+0.05*dy, ... 
                       ['Validation index = '  ...
                        num2str(Viva(na,nb))]) ; 
                  set(FIG,'DefaultTextHorizontalAlignment','right') ; 
                  text(1.3*K,ys(1)-0.4*dy,'<Press a key>') ;
            FIG = FIG+1 ; 
%             pause ;
            figure(FIG),clf ;
               fig_look(FIG,2) ; 
               pzmap(Mid,'SD',alpha) ; 
               title('Poles-Zeros representation') ; 
               xlabel('Real axis') ; 
               ylabel('Imaginary axis') ; 
               ys = axis ; 
               r = 's' ; 
               if (na==2)
                  r = [] ;
               end 
               text(0.8*ys(1),0.9*ys(4), ... 
                    [int2str(na-1) ' pole' r]) ; 
               r = 's' ; 
               if (nb==2)
                  r = [] ;
               end  
               text(0.8*ys(2),0.9*ys(4), ... 
                    [int2str(nb-1) ' zero' r]) ; 
               set(FIG,'DefaultTextHorizontalAlignment','left') ; 
               text(1.1*ys(2),ys(3),'<Press a key>') ;
            FIG = FIG-1 ; 
%             pause ;
         end  % [if (pf)]
      end  % [if ((na>1) | (nb>1)) ]
   end  % [for nb=1:Nb]
end  % [for na=1:Na]
if (~pf)
   war_err('      ... Done.') ; 
end 
% 
% Drawing useful surfaces for selecting the optimal structure
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Na = Na-1 ; 
Nb = Nb-1 ; 
figure(FIG),clf ;			% Noise variance.  
   fig_look(FIG,2) ; 
   [na,nb] = F_test2(Lambda,N) ; 
   Lambda(Lambda<eps) = eps ; 
   Mid = 10*log10(Lambda) ; 
   surf(0:Nb,0:Na,Mid) ; 
   ys = [min(min(Mid)) max(max(Mid))] ; 
   dy = ys(2) - ys(1) ; 
   axis([0 Nb 0 Na ys(1) ys(2)+0.2*dy]) ; 
   view([125,30]) ;
   title(['Estimated noise variance surface.',10,  ... 
          'F-test optimum: na = ' int2str(na-1) ... 
          ', nb = ' int2str(nb-1) '.']) ; 
   xlabel('nb') ; 
   ylabel('na') ; 
   zlabel('\lambda^2 [dB]') ; 
   text(nb-1,na-1,Mid(na,nb)+0.02*dy,'o') ; 
   set(FIG,'DefaultTextHorizontalAlignment','left') ; 
   text(Nb,1.5*Na,ys(1),'<Press a key>') ;
FIG = FIG+1 ; 
% pause
figure(FIG),clf ;			% Fitness: identification.  
   fig_look(FIG,2) ; 
   ys = [min(min(Eid)) max(max(Eid))] ; 
   [na,nb] = F_test2(ys(2)-Eid,N) ; 
   surf(0:Nb,0:Na,Eid) ; 
   dy = ys(2) - ys(1) ; 
   axis([0 Nb 0 Na ys(1) ys(2)+0.2*dy]) ; 
   view([125,30]) ;
   title(['Fitness values: identification data. ',10, ... 
          'F-test optimum: na = ' int2str(na-1) ... 
          ', nb = ' int2str(nb-1) '.']) ; 
   xlabel('nb') ; 
   ylabel('na') ; 
   zlabel('E_N [%]') ; 
   text(nb-1,na-1,Eid(na,nb)+0.02*dy,'o') ; 
   set(FIG,'DefaultTextHorizontalAlignment','left') ; 
   text(Nb,1.5*Na,ys(1),'<Press a key>') ;
FIG = FIG+1 ; 
% pause
figure(FIG),clf ;			% Fitness: validation.  
   fig_look(FIG,2) ; 
   ys = [min(min(Eva)) max(max(Eva))] ; 
   [na,nb] = F_test2(ys(2)-Eva,N) ; 
   surf(0:Nb,0:Na,Eva) ; 
   dy = ys(2) - ys(1) ; 
   axis([0 Nb 0 Na ys(1) ys(2)+0.2*dy]) ; 
   view([125,30]) ;
   title(['Fitness values: validation data. ',10, ... 
          'F-test optimum: na = ' int2str(na-1) ... 
          ', nb = ' int2str(nb-1) '.']) ; 
   xlabel('nb') ; 
   ylabel('na') ; 
   zlabel('E_N [%]') ; 
   text(nb-1,na-1,Eva(na,nb)+0.02*dy,'o') ; 
   set(FIG,'DefaultTextHorizontalAlignment','left') ; 
   text(Nb,1.5*Na,ys(1),'<Press a key>') ;
FIG = FIG+1 ; 
% pause
figure(FIG),clf ;			% GAIC-Rissanen.  
   fig_look(FIG,2) ; 
   [na,nb,Mid] = GAIC_R2(Lambda,N) ; 
   surf(0:Nb,0:Na,Mid) ; 
   ys = [min(min(Mid)) max(max(Mid))] ; 
   dy = ys(2) - ys(1) ; 
   axis([0 Nb 0 Na ys(1) ys(2)+0.2*dy]) ; 
   view([125,30]) ;
   title(['Akaike-Rissanen criterion. ',10, ... 
          'Optimum: na = ' int2str(na-1) ... 
          ', nb = ' int2str(nb-1) '.']) ; 
   xlabel('nb') ; 
   ylabel('na') ; 
   zlabel('GAIC-R') ; 
   text(nb-1,na-1,Mid(na,nb)+0.02*dy,'o') ; 
   set(FIG,'DefaultTextHorizontalAlignment','left') ; 
   text(Nb,1.5*Na,ys(1),'<Press a key>') ;
FIG = FIG+1 ; 
% pause
% 
% Selecting the optimal structure
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
na = input('    # Insert optimal indices [na nb]: ') ; 
na = abs(round(na(1:2))) ; 
nb = min(Nb,na(2))+1 ; 
na = min(Na,na(1))+1 ; 
Mid = M{na,nb} ; 
Yid = Yid{na,nb} ; 
Yva = Yva{na,nb} ; 
PEid = PEid{na,nb}.y ; 
PEva = PEva{na,nb}.y ; 
Eid = Eid(na,nb) ; 
Eva = Eva(na,nb) ; 
Viid = Viid(na,nb) ; 
Viva = Viva(na,nb) ; 
war_err('    o Optimum model: ') ; 
Mid
war_err([blanks(25) '<Press a key>']) ; 
% pause
% 
% Plotting model performances
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
figure(FIG),clf ;
   fig_look(FIG,1.5) ; 
   subplot(321)
      plot(1:N,Did.y,'-b',1:N,Yid,'-r') ; 
      title('Identification data') ; 
      ylabel('Outputs') ; 
      ys = [min(min(Did.y),min(Yid)) ... 
            max(max(Did.y),max(Yid))] ; 
      dy = ys(2)-ys(1) ; 
      axis([0 N+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
      text(1.22*N,ys(2)+0.45*dy, ... 
           ['na = ' int2str(na-1) ... 
            ' | nb = ' int2str(nb-1)]) ; 
      text(N/2,ys(2)+0.05*dy, ... 
           ['Fitness E_N = ' sprintf('%g',Eid) ' %']) ;
   subplot(322)
      plot(1:N,Dva.y,'-b',1:N,Yva,'-r') ; 
      title('Validation data') ; 
      ylabel('Outputs') ; 
      ys = [min(min(Dva.y),min(Yva)) ... 
            max(max(Dva.y),max(Yva))] ; 
      dy = ys(2)-ys(1) ; 
      axis([0 N+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
      text(N/2,ys(2)+0.05*dy, ... 
           ['Fitness E_N = ' sprintf('%g',Eva) ' %']) ;
      set(FIG,'DefaultTextHorizontalAlignment','left') ; 
      legend('y','ym') ; 
      set(FIG,'DefaultTextHorizontalAlignment','center') ; 
   subplot(323)
      plot(1:N,PEid,'-m') ; 
      ylabel('Prediction error') ; 
      ys = [min(PEid) max(PEid)] ; 
      dy = ys(2)-ys(1) ; 
      axis([0 N+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
      text(N/2,ys(2)+0.07*dy, ... 
           ['\lambda^2 = ' sprintf('%g',std(PEid,1)^2)]) ;
   subplot(324)
      plot(1:N,PEva,'-m') ; 
      ylabel('Prediction error') ; 
      ys = [min(PEva) max(PEva)] ; 
      dy = ys(2)-ys(1) ; 
      axis([0 N+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
      text(N/2,ys(2)+0.07*dy, ... 
           ['\lambda^2 = ' sprintf('%g',std(PEva,1)^2)]) ; 
   subplot(325)
      set(FIG,'DefaultLineLineWidth',0.5) ; 
      set(FIG,'DefaultLineMarkerSize',2) ; 
      [r,K] = xcov(PEid,'unbiased') ; 
      r = r(K>=0) ; 
      K = ceil(length(r)/2) ; 
      r = r(1:K) ; 
      stem(1:K,r,'-g','filled') ; 
      xlabel('Normalized time') ; 
      ylabel('Auto-covariance') ; 
      ys = [min(r) max(r)] ; 
      dy = ys(2)-ys(1) ; 
      axis([0 K+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
      text(K/2,ys(2)+0.05*dy, ... 
           ['Validation index = ' num2str(Viid)]) ; 
   subplot(326)
      [r,K] = xcov(PEva,'unbiased') ; 
      r = r(K>=0) ; 
      K = ceil(length(r)/2) ; 
      r = r(1:K) ; 
      stem(1:K,r,'-g','filled') ; 
      xlabel('Normalized time') ; 
      ylabel('Auto-covariance') ; 
      ys = [min(r) max(r)] ; 
      dy = ys(2)-ys(1) ; 
      axis([0 K+1 ys(1)-0.05*dy ys(2)+0.2*dy]) ;
      text(K/2,ys(2)+0.05*dy, ... 
           ['Validation index = ' num2str(Viva)]) ; 
      set(FIG,'DefaultTextHorizontalAlignment','right') ; 
      text(1.3*K,ys(1)-0.4*dy,'<Press a key>') ;
FIG = FIG+1 ; 
% pause ;
figure(FIG),clf ;
   fig_look(FIG,2) ; 
   pzmap(Mid,'SD',alpha) ; 
   title('Poles-Zeros representation') ; 
   xlabel('Real axis') ; 
   ylabel('Imaginary axis') ; 
   ys = axis ; 
   r = 's' ; 
   if (na==2)
      r = [] ;
   end 
   text(0.8*ys(1),0.9*ys(4), ... 
        [int2str(na-1) ' pole' r]) ; 
   r = 's' ; 
   if (nb==2)
      r = [] ;
   end 
   text(0.8*ys(2),0.9*ys(4), ... 
        [int2str(nb-1) ' zero' r]) ; 
%
% END
%
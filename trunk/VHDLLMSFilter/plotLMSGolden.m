load 'out_arch_left.txt'
load 'NoiseSignal.txt'
x=[1:1:size(NoiseSignal)]; 
figure(1)
plot(out_arch_left);
xlabel('Sample N')
ylabel('Fixed point')
title('LMS filtered signal (11 taps)')
figure(2)
plot(x,NoiseSignal,x,out_arch_left,'r')
xlabel('Sample N')
ylabel('Fixed point')
title('Architecture Level (11 taps)')

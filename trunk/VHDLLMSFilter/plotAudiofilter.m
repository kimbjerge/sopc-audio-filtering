load 'NoiseSignal.txt'
x=[1:1:size(NoiseSignal)]; 
figure(1)
plot(NoiseSignal);
xlabel('Sample N')
ylabel('Fixed point')
title('Noise and Signal')

figure(2)
load 'Noise.txt'
plot(Noise);
xlabel('Sample N')
ylabel('Fixed point')
title('Noise')

figure(3)
load 'leftout.txt'
load 'leftout_transposed.txt'
hold on
plot(leftout,'b')
plot(leftout_transposed,'r')
hold off
xlabel('Sample N')
ylabel('Fixed point')
title('Left channel')

figure(4)
load 'rightout.txt'
load 'rightout_transposed.txt'
hold on
plot(rightout,'b')
plot(rightout_transposed,'r')
hold off
xlabel('Sample N')
ylabel('Fixed point')
title('Right channel')

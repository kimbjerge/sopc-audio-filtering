function [] = SaveAsFixedInFile(h, name)
%% Converts vector h to 1.23 and save in file given by name
% Convert input vector to 1.23 fixed point format 
h24 = h*2^23;

% Modified for Matlab 7
fid = fopen(name, 'w');
for i=1:length(h24)
    xtext = num2str(round(h24(i)));
    fprintf(fid, '%s\n', xtext);
end
fclose(fid);

end

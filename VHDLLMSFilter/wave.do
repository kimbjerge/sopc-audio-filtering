onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Analog-Step -height 74 -max 7043237.0000000009 -min -7069245.0 /audiolmsfilteropt_st_tb/audioout
add wave -noupdate -format Analog-Step -height 74 -max 7043237.0000000009 -min -7069245.0 /audiolmsfilteropt_st_tb/audioin
add wave -noupdate -format Logic /audiolmsfilteropt_st_tb/clk48khz
add wave -noupdate -format Logic /audiolmsfilteropt_st_tb/clk12mhz
add wave -noupdate -format Logic /audiolmsfilteropt_st_tb/ast_input_valid
add wave -noupdate -format Logic /audiolmsfilteropt_st_tb/ast_output_valid
add wave -noupdate -format Literal /audiolmsfilteropt_st_tb/ast_input_data
add wave -noupdate -format Analog-Step -height 74 -max 7043237.0000000009 -min -7069245.0 /audiolmsfilteropt_st_tb/ast_output_data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5625000 ns} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 44
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {3494331 ns} {13262077 ns}

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /audiolmsfilter_tb/clock
add wave -noupdate /audiolmsfilter_tb/reset
add wave -noupdate /audiolmsfilter_tb/audioclk12mhz
add wave -noupdate -format Analog-Step -height 74 -max 8970.0 -min -8885.0 /audiolmsfilter_tb/audioout
add wave -noupdate -format Analog-Step -height 74 -max 27175.999999999996 -min -27256.0 /audiolmsfilter_tb/audioin
add wave -noupdate /audiolmsfilter_tb/audiosync
add wave -noupdate /audiolmsfilter_tb/avs_write
add wave -noupdate /audiolmsfilter_tb/avs_read
add wave -noupdate /audiolmsfilter_tb/avs_cs
add wave -noupdate /audiolmsfilter_tb/avs_address
add wave -noupdate /audiolmsfilter_tb/avs_writedata
add wave -noupdate /audiolmsfilter_tb/avs_readdata
add wave -noupdate /audiolmsfilter_tb/clk
add wave -noupdate /audiolmsfilter_tb/clk12mhz
add wave -noupdate /audiolmsfilter_tb/clk48khz
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {770840000 ps} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {10500 us}

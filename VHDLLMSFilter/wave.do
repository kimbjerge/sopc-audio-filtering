onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /firfilter_iis2st_tb/reset_n
add wave -noupdate -format Logic /firfilter_iis2st_tb/ast_clk
add wave -noupdate -format Analog-Step -height 74 -max 47.0 -radix decimal /firfilter_iis2st_tb/ast_sink_data
add wave -noupdate -format Logic /firfilter_iis2st_tb/ast_sink_ready
add wave -noupdate -format Logic /firfilter_iis2st_tb/ast_sink_valid
add wave -noupdate -format Literal /firfilter_iis2st_tb/ast_sink_error
add wave -noupdate -format Literal /firfilter_iis2st_tb/ast_source_data
add wave -noupdate -format Logic /firfilter_iis2st_tb/ast_source_ready
add wave -noupdate -format Logic /firfilter_iis2st_tb/ast_source_valid
add wave -noupdate -format Literal /firfilter_iis2st_tb/ast_source_error
add wave -noupdate -format Logic /firfilter_iis2st_tb/adcdat
add wave -noupdate -format Logic /firfilter_iis2st_tb/adclrck
add wave -noupdate -format Logic /firfilter_iis2st_tb/dacdat
add wave -noupdate -format Logic /firfilter_iis2st_tb/daclrck
add wave -noupdate -format Logic /firfilter_iis2st_tb/bitclk
add wave -noupdate -format Literal /firfilter_iis2st_tb/lefti2svalue
add wave -noupdate -format Literal /firfilter_iis2st_tb/righti2svalue
add wave -noupdate -format Literal /firfilter_iis2st_tb/adcvalue
add wave -noupdate -format Literal -max 64.0 -radix decimal /firfilter_iis2st_tb/dacvalue
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {208552 ns} 0}
configure wave -namecolwidth 287
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
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {986624 ns}

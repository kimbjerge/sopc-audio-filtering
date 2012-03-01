onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /firfilter_tb/clk
add wave -noupdate -format Logic /firfilter_tb/clk48khz
add wave -noupdate -format Logic /firfilter_tb/reset_n
add wave -noupdate -format Logic /firfilter_tb/coeff_in_clk
add wave -noupdate -format Logic /firfilter_tb/coeff_in_areset
add wave -noupdate -format Literal /firfilter_tb/ast_sink_data
add wave -noupdate -format Logic /firfilter_tb/ast_sink_ready
add wave -noupdate -format Logic /firfilter_tb/ast_sink_valid
add wave -noupdate -format Literal /firfilter_tb/ast_sink_error
add wave -noupdate -format Analog-Step -height 74 -max 47.0 -radix decimal /firfilter_tb/ast_source_data
add wave -noupdate -format Logic /firfilter_tb/ast_source_ready
add wave -noupdate -format Logic /firfilter_tb/ast_source_valid
add wave -noupdate -format Literal /firfilter_tb/ast_source_error
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {171269 ns} 0}
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
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1050 us}

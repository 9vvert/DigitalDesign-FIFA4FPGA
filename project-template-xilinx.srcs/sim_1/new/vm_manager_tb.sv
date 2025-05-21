/***************  显存管理器   ***************/
`timescale 1ns/1ps
import type_declare::*;
module vm_manager_tb;
    // Clock and reset
    reg clk;
    reg rst;
    reg hdmi_clk;
    reg hdmi_cnt;
    // Clock generation
    initial begin
        clk = 0;
        hdmi_clk = 0;
        hdmi_cnt = 0;
    end
    always #5 clk = ~clk;       // clk 100MHz

    always@(posedge clk)begin
        if(hdmi_cnt == 1)begin
            hdmi_clk = ~hdmi_clk;
            hdmi_cnt = 0;
        end else begin
            hdmi_cnt = 1;
        end
    end
    // Reset generation
    initial begin
        rst = 0;
        #50;
        rst = 1;
        #50
        rst = 0;
    end
    wire ui_clk;
    wire batch_free;
    reg [11:0] y_pos[OBJ_NUM-1:0];
    Render_Param_t in_render_param[OBJ_NUM-1:0]; 
    wire [31:0] write_data;
    wire [14:0] write_addr;
    wire write_enable;

    video #(TEST_WIDTH, TEST_HSIZE, TEST_HFP, TEST_HSP, TEST_HMAX, TEST_VSIZE, TEST_VFP, TEST_VFP, TEST_VMAX, TEST_HSPP, TEST_VSPP)
    u_video
    (
        .ui_clk(ui_clk),
        .fill_batch(batch_free),
        .write_data(write_data),            // 接受RAM控制信息
        .write_addr(write_addr),
        .write_enable(write_enable),
        .clk(hdmi_clk)
    );
    vm_manager u_vm_manager(
        .clk_100m(clk),
        .rst(rst),
        .out_ui_clk(ui_clk),
        .write_data(write_data),            // 输出RAM控制信息
        .write_addr(write_addr),
        .write_enable(write_enable),
        .y_pos(y_pos),
        .batch_free(batch_free),
        .in_render_param(in_render_param)
    );
    

    initial begin
        $dumpfile("vm_manager_tb.vcd");
        $dumpvars(0, vm_manager_tb);
        #5
        y_pos[0] = 20;
        in_render_param[0] = '{render_type:1, h_pos: 64, v_pos:128, angle: 9, stat: 0, width: 32, height:32};
        y_pos[1] = 10;
        in_render_param[1] = '{render_type:2, h_pos: 128, v_pos:64, angle: 18, stat: 2, width: 32, height:32};
        #10000;
    end

endmodule
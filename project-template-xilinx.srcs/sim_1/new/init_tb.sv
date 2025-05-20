`timescale 1ns/1ps

module init_tb;


    // Clock and reset
    reg clk;
    reg rst;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;       // clk 100MHz

    // Reset generation
    initial begin
        rst = 0;
        #50;
        rst = 1;
        #50
        rst = 0;
    end
    
    /**************  模拟SD卡 **************/
    reg read_start;
    wire read_end;
    reg [31:0] sd_src_addr;
    reg [7:0] mem [511:0]; // 模拟存储区
    // Fake SD card model
    fake_sd u_fake_sd (
        .clk_100m (clk),
        .rst (rst),
        .read_start (read_start),
        .read_end (read_end),
        .sd_src_addr (sd_src_addr),
        .mem (mem)
    );
    /**************  模拟SDRAM **************/
    wire ui_clk;
    wire ui_rst;
    wire init_calib_complete;
    reg [1:0] sdram_cmd;
    reg [29:0] operate_addr;
    reg [63:0] write_data;
    wire [63:0] read_data;
    reg cmd_done;
    // Fake SDRAM model
    fake_sdram u_fake_sdram (
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_rst),
        .init_calib_complete(init_calib_complete),
        .sdram_cmd(sdram_cmd),
        .operate_addr(operate_addr),
        .write_data(write_data),
        .read_data(read_data),
        .cmd_done(cmd_done)
    );

    /****************  显存初始化 **************/
    reg init_start;
    wire init_end;
    vm_init dut (
        .ui_clk         (ui_clk),
        .ui_clk_sync_rst(ui_rst),
        .init_start     (init_start),
        .init_end       (init_end),
        .sd_buffer      (mem),
        .sd_read_end    (read_end),
        .cmd_done       (cmd_done),
        .sd_read_start  (read_start),
        .curr_sd_addr   (sd_src_addr),
        .sdram_cmd      (sdram_cmd),
        .curr_sdram_addr(operate_addr),
        .sdram_buffer   (write_data)
    );
    // Simulation control
    initial begin
        $dumpfile("init_tb.vcd");
        $dumpvars(0, init_tb);
        #100;
        init_start = 1;
        #10000;
        $finish;
    end

endmodule
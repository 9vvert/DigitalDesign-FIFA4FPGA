//[TODO] sdram, sdcard以及上层时钟的频率不同，需要使用一个统一的时钟循环！
module sdram_IO(
    //下面输出SDRAM的时钟，用于和显存相关的活动
    output wire ui_clk,
    output wire ui_clk_sync_rst,
    output wire init_calib_complete,  // 是否完成 DDR3 SDRAM 初始化，当检测到高电平的时候，表明SDRAM正式可用
    // sdram接口
    inout  wire [7 :0] ddr3_dq,
    inout  wire [0 :0] ddr3_dqs_n,
    inout  wire [0 :0] ddr3_dqs_p,
    output wire [15:0] ddr3_addr,
    output wire [2 :0] ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire [0 :0] ddr3_ck_p,
    output wire [0 :0] ddr3_ck_n,
    output wire [0 :0] ddr3_cke,
    output wire [0 :0] ddr3_cs_n,
    output wire [0 :0] ddr3_dm,
    output wire [0 :0] ddr3_odt,
    //
    input sys_clk_i,  // 400MHz
    input clk_ref_i,  // 200MHz
    input sys_rst,
    //对外暴露的接口
    input [1:0] sdram_cmd,          //命令，  0无效，1读取，2写入
    input [29:0] operate_addr,      //地址
    input [63:0] write_data,
    output reg [63:0] read_data,
    output reg cmd_done             //这一轮命令结束

);

    
    localparam [2:0] IDLE = 3'd0, WAIT_INIT = 3'd1, READ_CMD = 3'd2, 
    READ_DATA = 3'd3, WRITE_CMD = 3'd4, WRITE_DATA = 3'd5, DONE = 3'd6;

    
    wire [11:0] device_temp;

    reg [29:0] app_addr;
    reg [2:0] app_cmd;
    reg app_en;
    wire app_rdy;

    reg [63:0] app_wdf_data;
    reg app_wdf_end;
    reg [7:0] app_wdf_mask;
    reg app_wdf_wren;
    wire app_wdf_rdy;

    wire [63:0] app_rd_data;
    wire app_rd_data_end;
    wire app_rd_data_valid;

    reg [2:0] state;
    reg [1:0] delay_counter;
    always_ff @ (posedge ui_clk) begin
        if (ui_clk_sync_rst) begin
            state <= WAIT_INIT;
            app_addr <= 30'b0;
            app_cmd <= 3'b0;
            app_en <= 1'b0;
            app_wdf_data <= 64'b0;
            app_wdf_end <= 1'b0;
            app_wdf_mask <= 8'h00;
            app_wdf_wren <= 1'b0;
            read_data <= 64'd0;
            cmd_done <= 1'b0;
            delay_counter <= 2'd0;
        end else begin
            if (state == WAIT_INIT) begin                // init只需要一次
                // wait for init_calib_complete
                if (init_calib_complete) begin
                    state <= IDLE;
                end
            end else if (state == IDLE) begin
                if(sdram_cmd == 1)begin
                    state <= READ_CMD;
                end else if(sdram_cmd == 2)begin
                    app_wdf_data <= write_data;     // 在这里就将待写入的数据填入缓存
                    state <= WRITE_CMD;
                end else begin
                    state <= IDLE;
                end
            end else if (state == WRITE_CMD) begin
                // send write command
                app_addr <= operate_addr;
                app_cmd <= 3'b000; // write
                app_en <= 1'b1;

                if (app_en && app_rdy) begin
                    // done
                    state <= WRITE_DATA;
                    app_en <= 1'b0;
                end
            end else if (state == WRITE_DATA) begin
                // send write data
                app_wdf_wren <= 1'b1;
                app_wdf_end <= 1'b1;

                if (app_wdf_wren && app_wdf_rdy) begin
                    // done
                    state <= DONE;
                    app_wdf_wren <= 1'b0;
                    app_wdf_end <= 1'b0;
                    cmd_done <= 1'b1;   //拉高一个周期
                end
            end else if (state == READ_CMD) begin
                // send read command
                app_addr <= operate_addr;
                app_cmd <= 3'b001; // read
                app_en <= 1'b1;

                if (app_en && app_rdy) begin
                    // done
                    state <= READ_DATA;
                    app_en <= 1'b0;
                end
            end else if (state == READ_DATA) begin
                // wait for data read
                if (app_rd_data_valid) begin        // 正式读取完毕
                    read_data <= app_rd_data;
                    cmd_done <= 1'b1;               //拉高一个周期
                    state <= DONE;
                end
            end else begin      // DONE
                if(delay_counter == 2'd0)begin
                    delay_counter <= 2'd1;
                end else begin
                    delay_counter <= 2'd0;
                    cmd_done <= 1'b0;               // TODO:这里的cmd_done应该进行延时，让外部能够捕捉到
                    state <= IDLE;
                end
            end
        end
    end

    mig_7series_0 u_mig (
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_cs_n(ddr3_cs_n),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt),

        .sys_clk_i(sys_clk_i),  // 400MHz
        .clk_ref_i(clk_ref_i),  // 200MHz
        .sys_rst(sys_rst),

        // command interface
        .app_addr(app_addr),
        .app_cmd(app_cmd),
        .app_en(app_en),
        .app_rdy(app_rdy),

        // write datapath
        .app_wdf_data(app_wdf_data),
        .app_wdf_end(app_wdf_end),
        .app_wdf_mask(app_wdf_mask),
        .app_wdf_wren(app_wdf_wren),
        .app_wdf_rdy(app_wdf_rdy),

        // read datapath
        .app_rd_data_end(app_rd_data_end),
        .app_rd_data_valid(app_rd_data_valid),
        .app_rd_data(app_rd_data),

        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_clk_sync_rst),
        .init_calib_complete(init_calib_complete),
        .device_temp(device_temp),
        .app_sr_req(1'b0),
        .app_ref_req(1'b0),
        .app_zq_req(1'b0)
    );
endmodule
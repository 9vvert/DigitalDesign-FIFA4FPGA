`timescale 1ns / 1ps

module mod_top (
    input wire clk_100m,          // 100MHz 主时钟
    input wire reset,             // 复位信号，高电平有效
    output wire [7:0] led_bit,    // LED 位信号
    output wire [3:0] led_com,    // LED 扫描信号

    // DDR3 SDRAM 接口
    inout wire [7:0] ddr3_dq,
    inout wire [0:0] ddr3_dqs_n,
    inout wire [0:0] ddr3_dqs_p,
    output wire [15:0] ddr3_addr,
    output wire [2:0] ddr3_ba,
    output wire ddr3_ras_n,
    output wire ddr3_cas_n,
    output wire ddr3_we_n,
    output wire ddr3_reset_n,
    output wire [0:0] ddr3_ck_p,
    output wire [0:0] ddr3_ck_n,
    output wire [0:0] ddr3_cke,
    output wire [0:0] ddr3_cs_n,
    output wire [0:0] ddr3_dm,
    output wire [0:0] ddr3_odt
);

    // 时钟信号
    wire clk_ddr;          // 400MHz 时钟
    wire clk_ref;          // 200MHz 参考时钟
    wire clk_locked;       // PLL 锁定信号
    wire ui_clk;           // MIG 用户时钟
    wire ui_clk_sync_rst;  // MIG 同步复位信号

    // MIG 状态信号
    wire init_calib_complete; // DDR3 初始化完成信号

    // PLL 实例化
    pll u_pll (
        .clk_in1(clk_100m),
        .reset(reset),
        .locked(clk_locked),
        .clk_out1(clk_ddr),
        .clk_out2(clk_ref)
    );

    // 图片初始化 ROM
    reg [7:0] rom_data[0:287999]; // 600x480 图片数据存储
    initial $readmemh("image.coe", rom_data); // 从 COE 文件加载数据

    // SDRAM 读写控制信号
    wire app_rdy;
    wire app_wdf_rdy;
    wire [63:0] app_rd_data;
    wire app_rd_data_valid;

    reg [29:0] rom_address;   // 当前 ROM 地址
    reg [63:0] write_data;    // SDRAM 写入数据
    reg write_enable;         // SDRAM 写使能
    wire read_enable = 1'b0;  // SDRAM 读使能（此处不需要）

    // SDRAM_RW_Module 实例化
    sdram_rw_module u_sdram_rw (
        .clk(ui_clk),
        .rst(ui_clk_sync_rst),
        .address(rom_address),
        .write_data(write_data),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .read_data(),
        .read_valid(),
        .app_rdy(app_rdy),
        .app_wdf_rdy(app_wdf_rdy),
        .app_addr(ddr3_addr),
        .app_cmd(),
        .app_en(),
        .app_wdf_data(ddr3_dq),
        .app_wdf_end(),
        .app_wdf_wren(),
        .app_rd_data(app_rd_data),
        .app_rd_data_valid(app_rd_data_valid)
    );

    // MIG 实例化
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
        .sys_clk_i(clk_ddr),
        .clk_ref_i(clk_ref),
        .sys_rst(!clk_locked),
        .app_addr(),
        .app_cmd(),
        .app_en(),
        .app_rdy(app_rdy),
        .app_wdf_data(),
        .app_wdf_end(),
        .app_wdf_mask(),
        .app_wdf_wren(),
        .app_wdf_rdy(app_wdf_rdy),
        .app_rd_data(app_rd_data),
        .app_rd_data_valid(app_rd_data_valid),
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_clk_sync_rst),
        .init_calib_complete(init_calib_complete)
    );

    // 状态机控制逻辑
    reg [2:0] state;
    always @(posedge ui_clk or posedge ui_clk_sync_rst) begin
        if (ui_clk_sync_rst) begin
            state <= 0;
            rom_address <= 0;
            write_enable <= 0;
        end else begin
            case (state)
                0: begin
                    // 等待 DDR3 初始化完成
                    if (init_calib_complete) begin
                        state <= 1;
                    end
                end
                1: begin
                    // 准备写数据
                    write_data <= {rom_data[rom_address + 7], rom_data[rom_address + 6],
                                   rom_data[rom_address + 5], rom_data[rom_address + 4],
                                   rom_data[rom_address + 3], rom_data[rom_address + 2],
                                   rom_data[rom_address + 1], rom_data[rom_address]};
                    write_enable <= 1;
                    state <= 2;
                end
                2: begin
                    // 检查是否可以写入
                    if (write_enable && app_rdy && app_wdf_rdy) begin
                        write_enable <= 0;
                        rom_address <= rom_address + 8; // 每次写入 8 字节
                        if (rom_address == 287992) begin
                            state <= 3; // 写入完成
                        end else begin
                            state <= 1; // 写入下一块
                        end
                    end
                end
                3: begin
                    // 写入完成状态
                    // 可以添加其他逻辑，例如验证数据或进入空闲状态
                end
            endcase
        end
    end

endmodule
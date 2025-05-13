`timescale 1ns / 1ps

module sdram_rw_module (
    input  wire         clk,              // 系统时钟
    input  wire         rst,              // 复位信号，高电平有效
    input  wire [29:0]  address,          // 目标地址
    input  wire [63:0]  write_data,       // 要写入的数据
    input  wire         write_enable,     // 写使能信号，高电平有效
    input  wire         read_enable,      // 读使能信号，高电平有效
    output reg  [63:0]  read_data,        // 读取的数据
    output reg          read_valid,       // 读取数据有效信号

    // MIG 接口
    input  wire         app_rdy,          // MIG 就绪信号
    input  wire         app_wdf_rdy,      // MIG 写数据路径就绪信号
    output reg  [29:0]  app_addr,         // MIG 地址
    output reg  [2:0]   app_cmd,          // MIG 命令
    output reg          app_en,           // MIG 使能信号
    output reg  [63:0]  app_wdf_data,     // MIG 写数据
    output reg          app_wdf_end,      // MIG 写传输结束信号
    output reg          app_wdf_wren,     // MIG 写使能信号
    input  wire [63:0]  app_rd_data,      // MIG 读取的数据
    input  wire         app_rd_data_valid // MIG 读取数据有效信号
);

    // 状态机状态定义
    localparam IDLE  = 3'b000;
    localparam WRITE = 3'b001;
    localparam READ  = 3'b010;
    localparam WAIT  = 3'b011;

    reg [2:0] state, next_state;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (write_enable && app_rdy && app_wdf_rdy) begin
                    next_state = WRITE;
                end else if (read_enable && app_rdy) begin
                    next_state = READ;
                end
            end
            WRITE: begin
                if (app_wdf_rdy) begin
                    next_state = IDLE;
                end
            end
            READ: begin
                if (app_rd_data_valid) begin
                    next_state = IDLE;
                end else begin
                    next_state = WAIT; // 等待读取数据有效
                end
            end
            WAIT: begin
                if (app_rd_data_valid) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // 控制逻辑
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            app_addr       <= 30'b0;
            app_cmd        <= 3'b0;
            app_en         <= 1'b0;
            app_wdf_data   <= 64'b0;
            app_wdf_end    <= 1'b0;
            app_wdf_wren   <= 1'b0;
            read_data      <= 64'b0;
            read_valid     <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    app_en       <= 1'b0;
                    app_wdf_wren <= 1'b0;
                    read_valid   <= 1'b0;

                    if (write_enable) begin
                        app_addr     <= address;
                        app_cmd      <= 3'b000;  // 写命令
                        app_en       <= 1'b1;
                        app_wdf_data <= write_data;
                        app_wdf_end  <= 1'b1;
                        app_wdf_wren <= 1'b1;
                    end else if (read_enable) begin
                        app_addr <= address;
                        app_cmd  <= 3'b001;  // 读命令
                        app_en   <= 1'b1;
                    end
                end
                WRITE: begin
                    if (app_wdf_rdy) begin
                        app_wdf_wren <= 1'b0;
                        app_en       <= 1'b0;
                    end
                end
                READ: begin
                    app_en <= 1'b0;
                    if (app_rd_data_valid) begin
                        read_data  <= app_rd_data;
                        read_valid <= 1'b1;
                    end
                end
                WAIT: begin
                    if (app_rd_data_valid) begin
                        read_data  <= app_rd_data;
                        read_valid <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
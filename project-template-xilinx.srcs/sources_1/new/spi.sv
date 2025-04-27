`timescale 1ns / 1ps

// 使用1Mhz

module spi (
    input wire clk,          // 10MHz 输入时钟
    input wire rst,        // 复位信号，高电平有效？

    // PMOD 接口引脚映射
    // 并不暴露给使用接口
    output wire pmod_io1,    // MOSI
    input wire pmod_io2,     // MISO
    output wire pmod_io3,    // SCLK
    output wire pmod_io4,    // CS

    // SPI 数据接口
    // 真正使用的接口给，
    input wire [7:0] tx_data,  // 要发送的数据
    output reg [7:0] rx_data,  // 接收的数据
    input reg start,          // 开始信号
    output reg done            // 完成信号
);

    // 数据寄存器
    reg [7:0] shift_reg;      // 数据移位寄存器
    // 状态机定义
    localparam IDLE = 2'b00, SEND = 2'b01, RECEIVE = 2'b10, DONE = 2'b11;
    reg [1:0] state;          // 当前状态
    reg [2:0] bit_index;      // 位计数器 (0~7)


    // 片选信号 (低电平有效)
    assign pmod_io4 = (state == IDLE) ? 1'b1 : 1'b0; // 高电平空闲，低电平选中
    // MOSI 信号
    assign pmod_io1 = shift_reg[7];
    // SCLK 信号
    assign pmod_io3 = clk;

    // SPI 时钟分频逻辑
    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         clk_div <= 16'b0;
    //         spi_clk <= 1'b0;
    //     end else begin
    //         if (clk_div == CLK_DIV_MAX) begin
    //             clk_div <= 16'b0;
    //             spi_clk <= ~spi_clk; // 翻转 SPI 时钟
    //         end else begin
    //             clk_div <= clk_div + 1;
    //         end
    //     end
    // end

    // use rst_synced as asynchronous reset of all modules
    // 检测时钟边沿


    // 状态机逻辑
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 这是否算作异步复位？如果是的话，可能会导致时序问题，后续需要修改
            state <= IDLE;
            bit_index <= 3'b0;
            shift_reg <= 8'b0;
            rx_data <= 8'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SEND;
                        shift_reg <= tx_data; // 加载发送数据
                        bit_index <= 3'b0;
                    end
                end
                SEND: begin
                    if (clk) begin // 在时钟上升沿发送数据
                        shift_reg <= {shift_reg[6:0], 1'b0}; // 左移一位
                        state <= RECEIVE;
                    end
                end
                RECEIVE: begin
                    if (clk) begin // 在时钟沿接收数据
                        rx_data <= {rx_data[6:0], pmod_io2}; // 从 MISO 读取数据
                        if (bit_index == 3'b111) begin
                            state <= DONE; // 完成 8 位发送和接收
                        end else begin
                            bit_index <= (bit_index + 1);
                            state <= SEND;
                        end
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE; // 返回空闲状态
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
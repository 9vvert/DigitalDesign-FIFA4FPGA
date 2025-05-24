`timescale 1ns / 1ps

// 使用1Mhz
// 每次读取8bit
module spi (
    input wire clk,          // 100kHz spi时钟
    input wire rst,        // 复位信号，高电平有效

    // PMOD 接口引脚映射
    // 并不暴露给使用接口
    output reg pmod_io1,    // MOSI
    input reg pmod_io2,     // MISO
    output reg pmod_io3,    // SCLK

    // SPI 数据接口
    // 真正使用的接口给，
    input wire [7:0] cmd,     //从主机到手柄
    output reg [7:0] dat,    //从手柄到主机
    input wire start,   //用于控制状态的开始
    output reg done    //状态结束
);

    // 状态机定义
    localparam IDLE = 3'b000, CMD = 3'b001, DOWN = 3'b010, DAT = 3'b011, UP = 3'b100, DONE = 3'b101;
    reg [2:0] state;          // 当前状态

    reg [2:0] bit_index;      // 0~7，用来引用某一位

    reg done_delay_counter;

    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
            done_delay_counter <= 1'b0;
            bit_index <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    pmod_io3 <= 1'b1;   //保持SCLK为高
                    done_delay_counter <= 1'b0;
                    if(start == 1'b1) begin //外部需要保证一次Start拉高后及时再将其拉低
                        state <= CMD;       
                    end
                end
                CMD: begin
                    pmod_io1 <= cmd[bit_index]; // 发送命令位
                    state <= DOWN;
                end
                DOWN: begin
                    pmod_io3 <= 1'b0; // SCLK拉低
                    state <= DAT;
                end
                DAT: begin
                    dat[bit_index] <= pmod_io2; // 接收数据位
                    state <= UP;
                end
                UP: begin
                    pmod_io3 <= 1'b1; // SCLK拉高
                    if(bit_index == 3'b111) begin
                        bit_index <= 3'b000;
                        state <= DONE; // 完成 8 位发送和接收
                    end else begin
                        bit_index <= bit_index + 1; // 增加位计数器
                        state <= CMD; // 返回发送命令状态
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    if(done_delay_counter == 1'b1) begin    //起到了在一次读取后延时的作用
                        state <= IDLE;
                        done <= 1'b0;
                    end else begin
                        done_delay_counter <= done_delay_counter+1'b1;
                    end
                end
                    //同时保持clk为高电平，持续2周期
                default: state <= IDLE;
            endcase
        end
    end
endmodule
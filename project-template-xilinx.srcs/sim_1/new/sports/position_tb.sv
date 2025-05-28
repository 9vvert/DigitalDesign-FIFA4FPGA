/***************  显存管理器   ***************/
`timescale 1ns/1ps
import type_declare::*;
module position_tb;
    // Clock and reset
    reg clk;
    reg rst;
    // Clock generation
    initial begin
        clk = 0;
    end
    always #5 clk = ~clk;       // clk 100MHz
    wire clk_100m;
    assign clk_100m = clk;
    wire clk_locked;
    assign clk_locked = 1;
    // Reset generation
    initial begin
        rst = 0;
        #50;
        rst = 1;
        #50
        rst = 0;
    end


    /************** 正文 ******************/
    /*************  时钟生成  ****************/
    wire ui_clk;
    wire ui_rst;
    assign ui_clk = clk_100m;
    assign ui_rst = rst;
    reg ps2_clk;
    reg [9:0] ps2_clk_cnt;
    always @(posedge ui_clk) begin      // 使用ui_clk生成game_clk和ps2_clk，更加稳定
        if(ui_rst) begin
            ps2_clk <= 1'b0;
            ps2_clk_cnt <= 10'b0;
        end else begin
            if(ps2_clk_cnt == 10'd4) begin    // 500次反转，意味着频率是原来的1/1000，也就是100kHz (10us一次)
                ps2_clk <= ~ps2_clk; // 反转时钟
                ps2_clk_cnt <= 10'b0;
            end else begin
                ps2_clk_cnt <= ps2_clk_cnt + 10'b1;
            end
        end
    end
    // 生成game_clk的初始值
    //[TODO]迁移到game_top.sv
    reg game_clk;
    reg game_rst;      // ui_rst可能因为时间过短，无法支持ps2_clk和game_clk的初始化
    reg [31:0] game_rst_counter;
    reg [31:0] game_clk_cnt;
    // 为了仿真，将间隔调小
    always @(posedge ui_clk) begin
        if(ui_rst) begin
            game_clk <= 0;
            game_clk_cnt <= 0;
            game_rst <= 0;
            game_rst_counter <= 0;
        end else begin
            if(game_clk_cnt == 499) begin    //(1ms一次)
                game_clk <= ~game_clk; // 反转时钟
                game_clk_cnt <= 0;
            end else begin
                game_clk_cnt <= game_clk_cnt + 1;
            end
            //让game_rst持续若干周期，保证能够初始化
            if(game_rst_counter == 4999)begin
                game_rst <= 1;
                game_rst_counter <= game_rst_counter + 1;
            end else if(game_rst_counter == 9999)begin
                game_rst <= 0;
                //这种情况下千万不要再递增game_rst_counter, 否则会周期性复位
            end else begin
                game_rst_counter <= game_rst_counter + 1;
            end
        end
    end

    /***************  game  ********************/
    PlayerInfo player_info[9:0];
    BallInfo ball_info;
    wire [5:0] game_bg;
    game u_game(
        .game_clk(game_clk),
        .ps2_clk(ps2_clk),
        .rst(game_rst),
        .ball_info(ball_info),
        .player_info(player_info),
        //
        .game_bg(game_bg)


    );


endmodule
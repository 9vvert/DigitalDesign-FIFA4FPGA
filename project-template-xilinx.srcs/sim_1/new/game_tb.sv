/***************  显存管理器   ***************/
`timescale 1ns/1ps
import type_declare::*;
module game_tb;
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
    
    /***********  渲染 *************/
    
    wire [31:0] write_data;
    wire [14:0] write_addr;
    wire write_enable;
    wire batch_free;                // 请求batch 的信号
    wire batch_zero;
    wire dark_begin;
    wire dark_end;
    wire light_begin;
    wire light_end;

    wire [5:0] output_bg_index;
    wire game_bg_change;
    wire bg_change_done;
    //过渡层
    Render_Param_t in_render_param[31:0];   // 来自sprite_generator
    
    sprite_generator u_sprite_generator(
        .sprite_generator_ui_clk(ui_clk),
        .ui_rst(ui_rst),
        .game_bg(game_bg),
        .player_info(player_info),
        .ball_info(ball_info),
        .render_param(in_render_param),      // 输出到in_render_param中，作为vm_manager的输入
        .output_bg_index(output_bg_index),
        .game_bg_change(game_bg_change),
        .bg_change_done(bg_change_done)     //[TODO]忘记写了
    );

    vm_manager u_vm_manager
    (
        .clk_100m(clk_100m),       // 100MHz
        .rst(rst),
        .clk_locked(clk_locked),     // 复位信号
        //数据，和game.sv对接 [TODO]
        .in_render_param(in_render_param),          //具体参数，用来表示渲染的位置，以及采用什么图片素材
        .input_bg_index(output_bg_index),
        .game_bg_change(game_bg_change),
        .bg_change_done(bg_change_done),
        //和video.sv对接的信号
        .batch_free(batch_free),       // 当RAM进行一轮交换后，会发送这个信号，并持续一段周期，保证能够接受到
        .batch_zero(batch_zero),        // 更加特殊的标记，意味着请求新一帧的第一个batch
        .light_begin(light_begin),
        .light_end(light_end),
        .dark_begin(dark_begin),
        .dark_end(dark_end),
        //[TODO]检查和switch中的宽度是否一致，以及在空闲时候，switch输出的值是否会干扰正常逻辑
        .write_data(write_data),   //[TODO]研究SRAM的字节序，注意进行顺序变换
        .write_addr(write_addr),   //每一个batch，write_addr都是从0开始逐渐增减，在video.sv中会再进行一轮变换
        .write_enable(write_enable),        //写入显存的使能信号
        .out_ui_clk(ui_clk),
        .out_ui_rst(ui_rst)
    );


    /*****************  输出显示  *********************/
    wire [11:0] hdata;  // 当前横坐标
    wire [11:0] vdata;  // 当前纵坐标
    wire [7:0] video_red; // 红色分量
    wire [7:0] video_green; // 绿色分量
    wire [7:0] video_blue; // 蓝色分量
    wire video_clk; // 像素时钟
    wire video_hsync;
    wire video_vsync;
    wire video_de; // 数据使能信号
    assign video_clk = clk_100m;
    video u_video
    (
        .ui_clk(ui_clk),
        .fill_batch(batch_free),
        .zero_batch(batch_zero),
        .dark_end(dark_end),
        .light_end(light_end),
        .dark_begin(dark_begin),
        .light_begin(light_begin),
        .write_data(write_data),
        .write_addr(write_addr),
        .write_enable(write_enable),
        .clk(video_clk),
        .hsync(video_hsync),
        .vsync(video_vsync),
        .hdata(hdata),
        .vdata(vdata),
        .red(video_red),         // output reg是时序逻辑，output wire是组合逻辑
        .green(video_green),
        .blue(video_blue),
        .data_enable(video_de)
    );

endmodule
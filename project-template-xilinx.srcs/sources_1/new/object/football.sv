// 足球模块
/*****************  使用约定  ******************/
//外界在保持being_held为高电平的时候，必须在每回合都传入master_* 这几个参数
//在为低电平的时候，必须提供init_* 这几个参数的初始值
import type_declare::BallInfo, type_declare::ConstrainedInit, type_declare::FreeInit;
module football
#(parameter INIT_X = 100, INIT_Y = 100, INIT_Z = 0)
(
    input football_game_clk,           //和游戏时钟频率相同
    input rst, 

    input being_held,       // 是否被持球（0代表自由状态，1代表被持球）
    // 在束缚状态下，其位置仅仅由外部输入决定(输入：master的坐标，球的角度，人和球的距离，计算出球的坐标)
    input ConstrainedInit const_init,
    // 在自由状态下，其运动由物理引擎驱动，但是初始可以赋予一个初速度，并自由决定方向（射门、传球过程）
    input FreeInit free_init,
    // 最终的输出
    output reg [1:0]pos_flag,       // 0正常， 1在左边球网，2在右边球网
    output BallInfo ball_info,
    output reg [11:0] football_pos
    
);
import TrianglevalLib::*;
    wire [11:0] pos_x;
    wire [11:0] pos_y;
    wire [11:0] pos_z;
    wire [7:0] speed;
    wire [7:0] angle;
    wire [7:0] vertical_speed;
    wire vertical_signal;
    wire [11:0] free_x;
    wire [11:0] free_y;
    wire [11:0] free_z;
    wire [11:0] const_x;
    wire [11:0] const_y;
    wire [11:0] const_z;

    reg [2:0] ball_anim_stat;        // 取值：1-3

    assign pos_x = being_held ? const_x : free_x;
    assign pos_y = being_held ? const_y : free_y;
    assign pos_z = being_held ? const_z : free_z;

    always@(posedge football_game_clk)begin
        ball_info.anim_stat <= ball_anim_stat;
        ball_info.x <= pos_x;
        ball_info.y <= pos_y;
        ball_info.z <= pos_z;
        ball_info.speed <= speed;
        ball_info.angle <= angle;
        ball_info.vertical_speed <= vertical_speed;
        ball_info.vertical_signal <= vertical_signal;
    end
    assign const_x = const_init.master_x;
    assign const_y = const_init.master_y;
    assign const_z = const_init.master_height;

    // 使用being_held作为set_enable使能，也就是在
    position_caculator #(.FOOTBALL(1), .X_MIN(LEFT_X), .X_MAX(RIGHT_X), .Y_MIN(BOTTOM_Y), .Y_MAX(TOP_Y),
            .INIT_X(635), .INIT_Y(335)) u_position_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .in_angle(angle),          // angle保持不变
        .in_speed(speed),
        .out_x(free_x),
        .out_y(free_y),
        .set_pos_enable(being_held),
        .set_x_val(const_x),              
        .set_y_val(const_y)
    );
    vertical_position_caculator u_vertical_position_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .in_vertical_speed(vertical_speed),
        .in_vertical_signal(vertical_signal),
        .out_z(free_z),
        .set_pos_enable(being_held),
        .set_z_val(const_z)
    );
    /***************** 角度  *****************/

    angle_caculator u_angle_caculator
    (
        .game_clk(football_game_clk),
        .rst(rst),
        .delay(0),
        .enable(0),
        .signal(0),       // 0代表顺时针，1代表逆时针
        .angle(angle),
        .set_angle_enable(being_held),
        .set_angle_val(free_init.init_angle)
        
    );

    /***************** 速度计算****************/
    wire A_enable;
    wire VA_enable;  //垂直加速度使能
    assign A_enable = (pos_z == 0) & (speed > 0);
    assign VA_enable = (pos_z > 0) & (~being_held);     // 在空中而且处于自由态时，有加速度
    speed_caculator #(.A_T(400)) u_speed_caculator
    (
        .game_clk(football_game_clk),
        .rst(rst),
        .enable(A_enable),
        .signal(1),         // 一直减速
        .speed(speed),
        .set_speed_enable(being_held),
        .set_speed_val(free_init.init_speed)
    );
    vertical_speed_caculator u_vertical_speed_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .enable(VA_enable),         // 这里不用加速度方向（重力加速度恒向下）
        .speed_signal(vertical_signal),
        .speed(vertical_speed),
        .tmp_z(pos_z),
        .set_speed_enable(being_held),
        .set_speed_val(free_init.init_vertical_speed),
        .set_speed_signal(free_init.init_vertical_signal)
    );

    /***************  足球动画   *************/
    // 在被带球的情况下，和持球者的速度一致


    reg [9:0] anim_counter;
    reg [9:0] anim_T;       //切换需要的时间
    reg [1:0] anim_switch_stat;
    wire [7:0] self_speed;
    assign self_speed = (being_held ? const_init.master_speed : (speed + vertical_speed) );
    always@(posedge football_game_clk)begin
        if(rst)begin
            anim_counter <= 0;
            anim_T <= 1000;
            anim_switch_stat <= 0;
            ball_anim_stat <= 1;
        end else begin
            if(anim_switch_stat == 0)begin
                if(self_speed == 0)begin
                    ball_anim_stat <= 1;
                    anim_counter <= 0;
                    anim_switch_stat <= 0;
                end else begin
                    anim_counter <= 0;
                    anim_switch_stat <= 1;  //进入计数状态
                    //这里的周期并不是严格按照比例
                    anim_T <= 500 - 40*(self_speed);    // 保证speed+vertical_speed不超过12
                end
            end else begin
                if(anim_counter >= anim_T)begin
                    anim_counter <= 0;
                    anim_switch_stat <= 0;
                    ball_anim_stat <= (
                        ball_anim_stat == 1 ? 2 :
                        ball_anim_stat == 2 ? 3 : 1
                    );
                end else begin
                    anim_counter <= anim_counter + 1;
                end
            end
        end
    end

    /************  监听足球位置  *****************/
    always@(posedge football_game_clk)begin
        if(rst)begin
            pos_flag <= 0;
        end else begin
            football_pos <= pos_x;
            if(pos_x < LEFT_NET_X2 - 12)begin
                pos_flag <= 1;
            end else if(pos_x > RIGHT_NET_X1 + 12)begin
                pos_flag <= 2;
            end else begin
                pos_flag <= 0;
            end
        end
    end

endmodule   
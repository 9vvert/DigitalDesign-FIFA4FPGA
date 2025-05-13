module Tackle_FSM
// TOL_DIS: 判定半径, TOL_ANGLE: 判定角度, （不需要判定速度）
#(parameter TOL_DIS1 = 40, TOL_DIS2 = 10, TOL_ANGLE = 9)
(
    input Tackle_FSM_game_clk,
    input rst,

    //和上层HFSM模块的通信协议，捕捉上升沿
    input tackle_start,
    output reg Tackle_FSM_done,
    //用于打断动作
    input cancel,

    input [15:0] player_x,
    input [15:0] player_y,
    input [7:0] player_angle,
    input [7:0] player_speed,
    input [15:0] football_x,
    input [15:0] football_y,
    input [15:0] football_z,
    //控制
    output reg A_enable,
    output reg A_signal,
    output reg W_enable,
    output reg W_signal,
    //向上层传递的信息，主要用于汇报动作是否成功
    output reg [1:0] message    // 1:成功， 2：失败， 0：未定义
);

`include "angle.sv"
`include "trangleval.sv"
`include "line.sv"
    /**************************************/
    //DIS_JUDGE: 距离判定。不论何时，一旦距离超过，就会导致状态机结束，返回失败
    //ANG_JUDGE: 角度判定，重点是“人和球连线的角度”和
    localparam IDLE = 6'd0, SOFT_JUDGE = 6'd1, STRICT_JUDGE = 6'd2, 
        FOLLOW = 6'd3, DONE = 6'd4;
    
    /**********  内置追随机   *********/
    reg follow_enable;
    reg follow_AE;
    reg follow_AS;
    reg follow_WE;
    reg follow_WS;
    follow u_follow(
        .game_clk(Tackle_FSM_game_clk),
        .rst(rst),
        .enable(follow_enable),       // 只在enable = 1时工作，而且会实时读取obj_angle, obj_speed, aim_speed的数值
        .obj_x(player_x),
        .obj_y(player_y),
        .obj_angle(player_angle),
        .obj_speed(player_speed),
        .aim_x(football_x),
        .aim_y(football_y),
    //输出的控制信号
        .A_enable(follow_AE),
        .A_signal(follow_AS),
        .W_enable(follow_WE),
        .W_signal(follow_WS)
    );
    //
    reg ready;
    reg last_tackle_start;    
    reg [5:0] Tackle_FSM_stat;

    reg [7:0] player_football_angle;       //张角
    reg [7:0] delta_angle;
    reg [1:0] delta_pos;   //相对位置

    always@(posedge Tackle_FSM_game_clk) begin
        if(rst) begin
            ready <= 1'b0;
            last_tackle_start <= 1'b0;
            Tackle_FSM_stat <= IDLE;
            follow_enable <= 1'b0;
            A_enable <= 1'b0;
            W_enable <= 1'b0;    
            Tackle_FSM_done <= 1'b0;
        end else begin
            ready = (last_tackle_start == 1'b0) && (tackle_start == 1'b1);
            last_tackle_start = tackle_start;   // 这里十分危险，一定要使用阻塞赋值
            if(Tackle_FSM_stat == IDLE) begin
                //捕捉ready的上升沿
                follow_enable <= 1'b0;     
                A_enable <= 1'b0;
                W_enable <= 1'b0;    
                if(ready) begin
                    Tackle_FSM_stat <= STRICT_JUDGE;
                end else begin
                    Tackle_FSM_stat <= IDLE;
                end
            end else if(Tackle_FSM_stat == STRICT_JUDGE) begin
                // STRICT_JUDGE: 同时判断距离和角度，如果都在合适范围内则成功，否则转入SOFT_JUDGE
                player_football_angle = vec2angle(.x1(player_x), .y1(player_y), .x2(football_x), .y2(football_y));
                delta_angle = rel_angle_val(player_angle, player_football_angle);
                delta_pos = rel_angle_pos(player_angle, player_football_angle);
                if(delta_angle < TOL_ANGLE && 
                compare_distance(.x1(player_x), .y1(player_y), .x2(football_x), .y2(football_y), .r(TOL_DIS2)) == 2) begin
                    message <= 2'd1;        //判定成功
                    Tackle_FSM_done <= 1'b1;
                    Tackle_FSM_stat <= DONE;
                end else begin
                    Tackle_FSM_stat <= SOFT_JUDGE;
                end
            end else if(Tackle_FSM_stat == SOFT_JUDGE) begin
                if(compare_distance(.x1(player_x), .y1(player_y), .x2(football_x), .y2(football_y), .r(TOL_DIS1)) == 1) begin
                    message <= 2'd2;    //距离超过指定距离，认为失败
                    Tackle_FSM_done <= 1'b1;
                    Tackle_FSM_stat <= DONE;
                end else begin
                    Tackle_FSM_stat <= FOLLOW;
                end
            end else if(Tackle_FSM_stat == FOLLOW) begin
                //调整角度
                follow_enable <= 1'b1;      // 至少进入一次FOLLOW状态后才能开启追随机
                A_enable <= follow_AE;
                A_signal <= follow_AS;
                W_enable <= follow_WE;
                W_signal <= follow_WS;      //及时传递信号
                Tackle_FSM_stat <= STRICT_JUDGE;
            end else if(Tackle_FSM_stat == DONE) begin
                follow_enable <= 1'b0;
                Tackle_FSM_done <= 1'b0;           //将信号再次拉低
                A_enable <= 1'b0;
                W_enable <= 1'b0;
                Tackle_FSM_stat <= IDLE;
            end else begin
                Tackle_FSM_stat <= DONE;
            end
        end
    end
endmodule
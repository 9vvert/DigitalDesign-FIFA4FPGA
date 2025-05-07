// 动作重新划分： M: 移动， H： 持球者动作   F: 自由人动作  D: 门将动作
`include "../../geometry/line.sv"

// 抢断状态自动机，上层模块必须确定，只有非持球人才能进入这个状态
interface player_info;    //当前其它球员的位置、角度等信息，以及球的位置
    logic [11:0] x;
    logic [11:0] y;
    logic [11:0] z;
    logic [7:0] angle;
    logic [7:0] speed;
    logic hold_stat;         // 0: 自由状态， 1： 携带球
endinterface 
interface football_info;
    logic [11:0]x;
    logic [11:0]y;
    logic [11:0]z;
    logic [7:0]angle;
    logic [7:0]speed;
    logic hold_stat;         // 0: 自由状态（受摩擦力、重力等物理因素控制）， 1：被携带状态
endinterface
module H_Tackle
// TOL_DIS: 判定半径, TOL_ANGLE: 判定角度, （不需要判定速度）
#(parameter TOL_DIS = 20, TOL_ANGLE = 9)
(
    input game_clk,
    input rst,

    input ready,    //进入动作
    output reg done,    //完成动作，用于释放action_mutex
    
    // 0为失败，1为成功
    output reg [3:0] result;    //向上层传递状态信息
    
    input [11:0] player_x;
    input [11:0] player_y;
    input [11:0] player_z;
    input [7:0] player_speed;
    input [7:0] player_angle;
    input [7:0] angular_period;     // 转动1个角度需要的game_clk周期，周期越短，角速度越大
    // 
    input [11:0] football_x;
    input [11:0] football_y;
    input [11:0] football_z;
    input [7:0] football_speed; //当人和足球的速度差距过大时，需要先减速

    output reg take_over_angle;     //设想：通过一个寄存器决定是否接管下一个游戏周期的角度
    output [7:0] next_player_speed;     // 注意：在执行某些动作的时候，会控制angle/speed等属性
    football_info curr_football;

);
    /**************************************/
    //DIS_JUDGE: 距离判定。不论何时，一旦距离超过，就会导致状态机结束，返回失败
    //ANG_JUDGE: 角度判定，重点是“人和球连线的角度”和
    localparam START = 3'd0, DIS_JUDGE = 3'd1, ANG_JUDGE = 3'd2, DONE = 3'd3;
    //
    
    reg [2:0] stat;

    reg [7:0] angular_period_counter;   //用于角速度计数；
    
    wire [7:0] player_football_angle;       //张角
    
    wire [7:0] delta_angle = rel_angle_val(player_angle, player_football_angle);
    wire [1:0] delta_pos = rel_angle_pos(player_angle, player_football_angle)

    reg dis_judge_flag; //因为涉及到2次距离检验，所以需要一个状态，0为第一次
    always@(posedge game_clk) begin
        if(rst) begin
            //
            done <= 1'b0;
            stat <= ;
            dis_judge_flag <= 1'b0;
            angular_period_counter <= 8'd0;
        end else begin
            if(stat == START) begin
                stat <= DIS_JUDGE;
            end else if(stat == DIS_JUDGE) begin
                if( compare_distance(player_x,player_y,football_x,football_y,TOL_DIS) == 2'd1 ) begin
                    // 距离超过半径，终止
                    result <= 4'd0;
                    stat <= DONE;
                end else begin
                    if(dis_judge_flag == 1'b0) begin
                        stat <= ANG_JUDGE;
                        dis_judge_flag <= 1'b1;
                    end else begin
                        result <= 4'd1; // 成功抢断
                        //[TODO]后续外部需要根据result更新球员和球的附属状态
                        stat <= DONE;
                    end
                end
            end else if(stat == ANG_JUDGE) begin
                // 潜在风险：如果张角和角色的方向同步旋转，那么会一直卡在这个状态（不过理论上几乎不会出现这种情况，暂时忽略）
                if(delta_angle > 9) begin
                    take_over_angle <= 1'b1;    //参与接管，也就是进入了方向锁定状态
                    if(angular_period_counter == angular_period) begin
                        angular_period_counter <= 8'd0; 
                        if(delta_pos == 2'd0) begin //在左侧
                            next_player_speed <= angle_sub(player_angle, 8'd1);
                            // [TODO]外部需要接受这个信号，并更新速度
                        end else begin
                            next_player_speed <= angle_add(player_angle, 8'd1);
                        end
                    end else begin
                        angular_period_counter <= angular_period_counter + 8'd1;
                    end
                    stat <= ANG_JUDGE;  
                end else begin
                    take_over_angle <= 1'b0;
                    stat <= DIS_JUDGE;
                end
            end else if(stat == DONE) begin

            end else begin
                result <= 4'd0; //异常状态，返回失败
                stat <= DONE;
            end


        end
    end
endmodule
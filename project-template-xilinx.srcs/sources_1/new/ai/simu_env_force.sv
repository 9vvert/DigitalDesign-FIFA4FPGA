
module simu_env_force
#(parameter TEAM=0)
(
    input simulator_game_clk,       // 游戏时钟
    input rst,
    //信息
    input [2:0]force_level,
    input PlayerInfo player_info[9:0],
    input PlayerInfo self_info,
    //输出模拟值
    output reg [11:0] env_x_pos,
    output reg [11:0] env_x_neg,
    output reg [11:0] env_y_pos,
    output reg [11:0] env_y_neg

);
    /********** 边界力场 *********/
    // 边界斥力
    wire [11:0] simu_line_x_pos1;
    wire [11:0] simu_line_x_neg1;
    wire [11:0] simu_line_y_pos1;
    wire [11:0] simu_line_y_neg1;
    simu_line_force #(.LINE_Y(TOP_Y+10))u_simu_line_force1(
        .simu_x_pos(simu_line_x_pos1),
        .simu_x_neg(simu_line_x_neg1),
        .simu_y_pos(simu_line_y_pos1),
        .simu_y_neg(simu_line_y_neg1),
        .self_info(self_info),
        .enable(1),         // 默认都启用
        .mode(1)            // 0为竖线，1为横线
    );
    wire [11:0] simu_line_x_pos2;
    wire [11:0] simu_line_x_neg2;
    wire [11:0] simu_line_y_pos2;
    wire [11:0] simu_line_y_neg2;
    simu_line_force #(.LINE_Y(BOTTOM_Y-10))u_simu_line_force2(
        .simu_x_pos(simu_line_x_pos2),
        .simu_x_neg(simu_line_x_neg2),
        .simu_y_pos(simu_line_y_pos2),
        .simu_y_neg(simu_line_y_neg2),
        .self_info(self_info),
        .enable(1),         // 默认都启用
        .mode(1)            // 0为竖线，1为横线
    );
    wire [11:0] simu_line_x_pos3;
    wire [11:0] simu_line_x_neg3;
    wire [11:0] simu_line_y_pos3;
    wire [11:0] simu_line_y_neg3;
    simu_line_force #(.LINE_X(LEFT_X-10))u_simu_line_force3(
        .simu_x_pos(simu_line_x_pos3),
        .simu_x_neg(simu_line_x_neg3),
        .simu_y_pos(simu_line_y_pos3),
        .simu_y_neg(simu_line_y_neg3),
        .self_info(self_info),
        .enable(1),         // 默认都启用
        .mode(0)            // 0为竖线，1为横线
    );
    wire [11:0] simu_line_x_pos4;
    wire [11:0] simu_line_x_neg4;
    wire [11:0] simu_line_y_pos4;
    wire [11:0] simu_line_y_neg4;
    simu_line_force #(.LINE_X(RIGHT_X+10))u_simu_line_force4(
        .simu_x_pos(simu_line_x_pos4),
        .simu_x_neg(simu_line_x_neg4),
        .simu_y_pos(simu_line_y_pos4),
        .simu_y_neg(simu_line_y_neg4),
        .self_info(self_info),
        .enable(1),         // 默认都启用
        .mode(0)            // 0为竖线，1为横线
    );
    /********* 点力场  *********/
    wire [11:0] simu_point_x_pos1;
    wire [11:0] simu_point_x_neg1;
    wire [11:0] simu_point_y_pos1;
    wire [11:0] simu_point_y_neg1;
    simu_point_force u_simu_point_force1(
        .simulator_game_clk(simulator_game_clk),
        .rst(rst),
        .self_info(self_info),
        .obj_info(player_info[(TEAM==0) ? 5 : 0]), 
        .level(force_level),                
        .simu_x_pos(simu_point_x_pos1),
        .simu_x_neg(simu_point_x_neg1),
        .simu_y_pos(simu_point_y_pos1),
        .simu_y_neg(simu_point_y_neg1)
    );
    wire [11:0] simu_point_x_pos2;
    wire [11:0] simu_point_x_neg2;
    wire [11:0] simu_point_y_pos2;
    wire [11:0] simu_point_y_neg2;
    simu_point_force u_simu_point_force2(
        .simulator_game_clk(simulator_game_clk),
        .rst(rst),
        .self_info(self_info),
        .obj_info(player_info[(TEAM==0) ? 6 : 1]),
        .level(force_level),                
        .simu_x_pos(simu_point_x_pos2),
        .simu_x_neg(simu_point_x_neg2),
        .simu_y_pos(simu_point_y_pos2),
        .simu_y_neg(simu_point_y_neg2)
    );
    wire [11:0] simu_point_x_pos3;
    wire [11:0] simu_point_x_neg3;
    wire [11:0] simu_point_y_pos3;
    wire [11:0] simu_point_y_neg3;
    simu_point_force u_simu_point_force3(
        .simulator_game_clk(simulator_game_clk),
        .rst(rst),
        .self_info(self_info),
        .obj_info(player_info[(TEAM==0) ? 7 : 2]), 
        .level(force_level),              
        .simu_x_pos(simu_point_x_pos3),
        .simu_x_neg(simu_point_x_neg3),
        .simu_y_pos(simu_point_y_pos3),
        .simu_y_neg(simu_point_y_neg3)
    );
    wire [11:0] simu_point_x_pos4;
    wire [11:0] simu_point_x_neg4;
    wire [11:0] simu_point_y_pos4;
    wire [11:0] simu_point_y_neg4;
    simu_point_force u_simu_point_force4(
        .simulator_game_clk(simulator_game_clk),
        .rst(rst),
        .self_info(self_info),
        .obj_info(player_info[(TEAM==0) ? 8 : 3]),
        .level(force_level),                
        .simu_x_pos(simu_point_x_pos4),
        .simu_x_neg(simu_point_x_neg4),
        .simu_y_pos(simu_point_y_pos4),
        .simu_y_neg(simu_point_y_neg4)
    );
    // 更新：删除门将
    /********* 环境力场计算 *********/
    always@(posedge simulator_game_clk)begin
        if(rst)begin
            env_x_pos <= 0;
            env_x_neg <= 0;
            env_y_pos <= 0;
            env_y_neg <= 0;
        end else begin
            // 环境力场计算
            env_x_pos <= simu_line_x_pos1 + simu_line_x_pos2 + simu_line_x_pos3 + simu_line_x_pos4 +
                     simu_point_x_pos1 + simu_point_x_pos2 + simu_point_x_pos3 + simu_point_x_pos4;
            env_x_neg <= simu_line_x_neg1 + simu_line_x_neg2 + simu_line_x_neg3 + simu_line_x_neg4 +
                     simu_point_x_neg1 + simu_point_x_neg2 + simu_point_x_neg3 + simu_point_x_neg4;
            env_y_pos <= simu_line_y_pos1 + simu_line_y_pos2 + simu_line_y_pos3 + simu_line_y_pos4 +
                     simu_point_y_pos1 + simu_point_y_pos2 + simu_point_y_pos3 + simu_point_y_pos4;
            env_y_neg <= simu_line_y_neg1 + simu_line_y_neg2 + simu_line_y_neg3 + simu_line_y_neg4 +
                     simu_point_y_neg1 + simu_point_y_neg2 + simu_point_y_neg3 + simu_point_y_neg4;
        end
    end


endmodule
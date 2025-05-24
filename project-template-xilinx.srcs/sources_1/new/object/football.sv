// 足球模块
/*****************  使用约定  ******************/
//外界在保持being_held为高电平的时候，必须在每回合都传入master_* 这几个参数
//在为低电平的时候，必须提供init_* 这几个参数的初始值
module football
#(parameter INIT_X = 100, INIT_Y = 100, INIT_Z = 0)
(
    input football_game_clk,           //和游戏时钟频率相同
    input rst, 

    input being_held,       // 是否被持球（0代表自由状态，1代表被持球）
    // 在束缚状态下，其位置仅仅由外部输入决定(输入：master的坐标，球的角度，人和球的距离，计算出球的坐标)
    input reg [15:0] master_x,
    input reg [15:0] master_y,
    input reg [15:0] master_height,     //外界输入的高度，用来直接设置球的高度
    input reg [7:0] master_angle,
    input reg [15:0] master_radius,     // radius自带12倍率（和sin, cos中的倍率一致）
    // 在自由状态下，其运动由物理引擎驱动，但是初始可以赋予一个初速度，并自由决定方向（射门、传球过程）
    input [7:0] init_angle,
    input [7:0] init_speed,
    input [7:0] init_vertical_speed,
    input init_vertical_signal,
    // 最终的输出
    output reg [15:0] pos_x,
    output reg [15:0] pos_y,
    output reg [15:0] pos_z,

    output reg [7:0] anim_stat
);
`include "trangleval.sv"
    // "run"部分，除了会受到转弯/动作的影响，其它情况下应该是能够独立完成的

    reg set_enable; // 共用一个重置信号

    /****************   坐标计算  *******************/
    reg [7:0] speed;
    reg [7:0] vertical_speed;    // z方向速度
    reg vertical_signal;         // z方向速度的方向
    // 这里对坐标加一层缓冲的目的是：可以选择性地使用position_caculator的值，在束缚状态下可以直接忽略
    reg [15:0] free_out_x;
    reg [15:0] free_out_y;
    reg [15:0] free_out_z;
    position_caculator #(.INIT_X(INIT_X), .INIT_Y(INIT_Y)) u_position_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .in_angle(init_angle),          // angle保持不变
        .in_speed(speed),
        .out_x(free_out_x),
        .out_y(free_out_y),
        .set_pos_enable(set_enable),
        .set_x_val(pos_x),              
        .set_y_val(pos_y)
    );
    vertical_position_caculator u_vertical_position_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .in_vertical_speed(vertical_speed),
        .in_vertical_signal(vertical_signal),
        .out_z(free_out_z),
        .set_pos_enable(set_enable),
        .set_z_val(pos_z)
    );

    /***************** 速度计算****************/
    reg A_enable;
    reg A_signal;
    reg VA_enable;  //垂直加速度使能
    reg VA_signal;  //垂直加速度方向
    speed_caculator u_speed_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .enable(A_enable),
        .signal(A_signal),
        .speed(speed),
        .set_speed_enable(set_enable),
        .set_speed_val(init_speed)
    );
    vertical_speed_caculator u_vertical_speed_caculator(
        .game_clk(football_game_clk),
        .rst(rst),
        .enable(VA_enable),         // 这里不用加速度方向（重力加速度恒向下）
        .speed_signal(vertical_signal),
        .speed(vertical_speed),
        .set_speed_enable(set_enable),
        .set_speed_val(init_vertical_speed),
        .set_speed_signal(init_vertical_signal)
    );

    /**************  简化模型，不会进行角度计算 ***************/
    // 仅仅通过INIT_angle来设置即可


    // 进入约束态/进入自由态/物理引擎模拟
    reg [5:0] football_stat;
    localparam [5:0] ENTER_CONST = 6'd0, ENTER_FREE = 6'd1, SIMU_FREE = 6'd2;   

    reg [5:0] simu_stat;    //在模拟过程中，有一定的时序需求
    always @(posedge football_game_clk) begin
        if(rst) begin
            set_enable <= 1'b0;
            A_enable <= 1'b0;
            VA_enable <= 1'b0;
            football_stat <= ENTER_FREE;
            pos_x <= INIT_X;
            pos_y <= INIT_Y;
            pos_z <= INIT_Z;
            simu_stat <= 6'd0;
        end else begin
            //每个时刻都先判断是自由状态还是束缚状态
            case(football_stat) 
                ENTER_CONST:
                //[TODO]这里没有进行坐标的约束计算
                    if(being_held == 1'b1) begin
                        football_stat <= ENTER_CONST;   // 保持约束态
                        pos_z <= master_height;
                        if(master_angle < 8'd18) begin
                            pos_x <= master_x + master_radius * sin(master_angle);
                            pos_y <= master_y + master_radius * cos(master_angle);
                        end else if(master_angle < 8'd36) begin
                            pos_x <= master_x + master_radius * cos(master_angle - 8'd18);
                            pos_y <= master_y - master_radius * sin(master_angle - 8'd18);
                        end else if(master_angle < 8'd54) begin
                            pos_x <= master_x - master_radius * sin(master_angle - 8'd36);
                            pos_y <= master_y - master_radius * cos(master_angle - 8'd36);
                        end else if(master_angle < 8'd72) begin
                            pos_x <= master_x - master_radius * cos(master_angle - 8'd54);
                            pos_y <= master_y + master_radius * sin(master_angle - 8'd54);
                        end else begin  // 0xFF没有方向 (不应出现，尽管摇杆可能有0xFF，但是人应该时刻都有一个0-71的角度)
                            pos_x <= pos_x;
                            pos_y <= pos_y;
                        end
                    end else begin
                        football_stat <= ENTER_FREE;
                    end
                ENTER_FREE:     // 刚进入free状态的时候，
                    if(being_held) begin
                        football_stat <= ENTER_CONST;
                    end else begin
                        simu_stat <= 6'd0;  //初始化simulation状态
                        // angle <= init_angle;
                        speed <= init_speed;
                        vertical_speed <= init_vertical_speed;
                        vertical_signal <= init_vertical_signal;
                        football_stat <= SIMU_FREE;
                    end
                SIMU_FREE:
                    if(being_held) begin
                        football_stat <= ENTER_CONST;
                        //[TODO] 现在存在的问题：如果直接进行状态切换，可能导致人和球之间的距离突变，后续可能需要进一步的平滑过渡
                    end else begin
                        football_stat <= SIMU_FREE;     
                        if(simu_stat < 6'd2) begin
                            set_enable <= 1'b1;     // 持续2周期
                            simu_stat <= simu_stat + 6'd1;
                        end else begin
                            set_enable <= 1'b0;     // 重新归0，标志着设置阶段结束，正式开始模拟
                            // 基本逻辑可以根据物理引擎模块独立计算出来，外部这里可以对一些特殊情况添加一些控制
                            
                            //触地
                            if(pos_z == 0 && vertical_signal == 1'b1) begin    // 触底：垂直速度记为0，同时禁用垂直加速度
                                vertical_speed <= 8'd0;
                                VA_enable <= 1'b0;
                            end else begin
                                VA_enable <= 1'b1;      // 只要在半空中，就启用重力加速度
                            end
                            //速度减为0
                            if(speed == 8'd0) begin
                                A_enable <= 1'b0;   
                            end else begin
                                A_enable <= 1'b1;       //速度非0，启用摩擦力
                            end
                            // 如果后续需要加速边界反弹的逻辑，也可以在这里加入
                        end
                        //在simu阶段，坚持从free_out_获得
                        //是否可能有抖动？后续需要模拟测试
                        pos_x <= free_out_x;
                        pos_y <= free_out_y;
                        pos_z <= free_out_z;
                    end
            endcase
        end
    end
endmodule   
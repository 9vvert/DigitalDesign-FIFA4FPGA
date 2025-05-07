// 足球运动员模块

// [TODO]如何选择游戏时钟的频率？

// [TODO]命令的优先级应该在ps2_decode过程中就完成，在这里已经是没有歧义的命令，一次至多执行一个A类动作（B类奔跑独立）

module player(
    input game_clk,           //和游戏时钟频率相同
    input rst, 

    input cmd_ctrl,   //是否由玩家控制，1代表玩家控制，0代表ai控制
    
    // 指令主要分为run 和 action两大类

    // run instr
    input [1:0] run_stat,    // 空闲、跑动、刹车、冲刺    
    input [7:0] left_angle,   // 手柄的转角，转向时，先减速，然后转向
    // action instr
    input 
    input [7:0] right_angle,

    //输出，用于 1.渲染  2.模块之间交互 3.AI参数
    output reg [9:0] pos_x,
    output reg [9:0] pos_y,
    output reg [9:0] pos_z,      // 初步设为恒等于0
    output reg [7:0] angle_next, //下一个时刻的角度
    output reg [7:0] speed_next, //下一个时刻的速度

    output reg [7:0] anim_stat  //用于渲染不同的运动员动作
    // 迈开腿这样的状态机切换频率，应该和人物的速度挂钩
);
    // 作为内部参数使用
    reg [7:0] curr_angle;     //当前的角度
    reg [7:0] curr_speed;  
    reg [9:0] curr_x;
    reg [9:0] curr_y;
    reg [9:0] curr_z;

    reg action_mutex;   //当人物做动作的时候，进入动作保护状态，防止频繁的状态打断造成的动作抽搐

    // "run"部分，除了会受到转弯/动作的影响，其它情况下应该是能够独立完成的
    always @(posedge game_clk) begin
        if(rst) begin
            action_mutex = 1'b0;
            //
        end else if(action_mutex) begin
            // 保护状态，按照动作自动机继续
        end else if(cmd_ctrl) begin
            //
        end else begin
            //
        end
    end

    // "action"部分
    
endmodule
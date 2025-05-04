// 足球运动员模块

// [TODO]如何选择游戏时钟的频率？


module player(
    input wire clk,           // 和游戏的帧率相同

    input wire [0:0] ai_ctrl;   //是否由ai接管，如果为0，则信号自动生成

    input wire[7:0] angle_curr;     //当前的角度
    input wire[7:0] angle_handle;   //手柄的转角（2个值不同步，有一定的角度延时，可以在不同的速度下有不同的转角周期）
    input wire[7:0] speed_curr;  
    

    input wire[3:0] interactive_stat;   //交互状态：自由/和身边的对手/锁定队友
    input wire[0:0] dash_stat;  //是否按下冲刺按钮      决定了下一时刻的速度和角度转向
    input wire[0:0] kick_stat;  //是否按下射门按钮      (长时间按下去会蓄力，松开射门)
    input wire[0:0] catch_stat;  //是否按下抢球按钮

    output reg[9:0] pos_x,
    output reg[9:0] pos_y;
    output reg[9:0] pos_z;      // 初步设为恒等于0
    output reg[7:0] angle_next; //下一个时刻的角度
    output reg[7:0] speed_next; //下一个时刻的速度

    output reg[5:0] anim_stat;  //用于渲染不同的运动员动作
    // 迈开腿这样的状态机切换频率，应该和人物的速度挂钩
);
    
endmodule
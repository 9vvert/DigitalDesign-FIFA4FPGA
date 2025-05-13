// 管理game中最顶层的一些变量：
// 可操作者和AI球员分布 / 持球者是谁 / 球的状态 / 


module controller(
    input controller_game_clk,
    input rst,

    input [15:0] tackle_signal,
    input [15:0] shoot_signal, 

    //对球的控制信号输入，在controller模块会进行仲裁
    constrained_init.input_modport in_const_1,
    constrained_init.input_modport in_const_6,

    free_init.input_modport in_free_1,
    free_init.input_modport in_free_6,
    
    //最终输出的对球控制信号
    output reg [15:0] master_x,
    output reg [15:0] master_y,
    output reg [15:0] master_height,
    output reg [7:0] master_angle,
    output reg [15:0] master_radius,
    output reg [7:0] init_speed,
    output reg [7:0] init_angle,
    output reg [7:0] init_vertical_speed,
    output reg init_vertical_signal,
    //人和球的状态输出
    output reg football_being_held,
    output reg [15:0] player_hold_stat   //内部保证：同一时间只有一个比特为1，

);
    reg [15:0] last_tackle_signal;
    reg [15:0] last_shoot_signal;
    

    always @(posedge controller_game_clk) begin
        if(rst) begin
            football_being_held <= 1'b0;
            player_hold_stat <= 16'd0;
            init_speed <= 8'd0;
            init_angle <= 8'd0;
            init_vertical_signal <= 1'b0;;
            init_vertical_speed <= 8'd0;
            last_tackle_signal <= 16'd0;
            last_shoot_signal <= 16'd0;
        end else begin
            /********** 球持有者 ************/
            //抢球判断，仅仅发生于tackle_signal的上升沿
            if(last_tackle_signal != tackle_signal) begin
                //开始判断，抢断优先于射门
                if (last_tackle_signal[0]==0 && tackle_signal[0]==1) begin
                    football_being_held = 1'b1;
                    player_hold_stat = 16'b0000000000000001;
                    
                end else if(last_tackle_signal[5]==0 && tackle_signal[5]==1) begin
                    football_being_held = 1'b1;
                    player_hold_stat = 16'b0000000000100000;
                end
            end
            last_tackle_signal <= tackle_signal;
            if(last_shoot_signal != shoot_signal)begin
                //射门判断
                if (last_shoot_signal[0]==0 && shoot_signal[0]==1) begin
                    football_being_held = 1'b0;
                    player_hold_stat = 16'd0;
                    init_speed <= in_free_1.init_speed;
                    init_angle <= in_free_1.init_angle;
                    init_vertical_speed <= in_free_1.init_vertical_speed;
                    init_vertical_signal <= in_free_1.init_vertical_signal;
                end else if(last_shoot_signal[5]==0 && shoot_signal[5]==1) begin
                    football_being_held = 1'b0;
                    player_hold_stat = 16'd0;
                    init_speed <= in_free_6.init_speed;
                    init_angle <= in_free_6.init_angle;
                    init_vertical_speed <= in_free_6.init_vertical_speed;
                    init_vertical_signal <= in_free_6.init_vertical_signal;
                end
            end
            last_shoot_signal <= shoot_signal;

            //const_parameter
            if(player_hold_stat[0])begin
                master_x <= in_const_1.master_x;
                master_y <= in_const_1.master_y;
                master_height <= in_const_1.master_height;
                master_angle <= in_const_1.master_angle;
                master_radius <= in_const_1.master_radius;
            end else if(player_hold_stat[5])begin
                master_x <= in_const_6.master_x;
                master_y <= in_const_6.master_y;
                master_height <= in_const_6.master_height;
                master_angle <= in_const_6.master_angle;
                master_radius <= in_const_6.master_radius;
            end

            /**************  可操纵角色切换  **************/
        end
    end

endmodule
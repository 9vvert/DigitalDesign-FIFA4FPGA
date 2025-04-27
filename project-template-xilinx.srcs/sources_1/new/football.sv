`timescale 1ns / 1ps
//
// WIDTH: bits in register hdata & vdata
// HSIZE: horizontal size of visible field 
// HFP: horizontal front of pulse
// HSP: horizontal stop of pulse
// HMAX: horizontal max size of value
// VSIZE: vertical size of visible field 
// VFP: vertical front of pulse
// VSP: vertical stop of pulse
// VMAX: vertical max size of value
// HSPP: horizontal synchro pulse polarity (0 - negative, 1 - positive)
// VSPP: vertical synchro pulse polarity (0 - negative, 1 - positive)
//
module football
//这里是接受的参数，在mod.top里已经赋值过了，下面的应该是缺省参数，填错了并不影响

(
    input wire clk,           // 和游戏的帧率相同
    input wire[7:0] angle_curr;     //球的运动由人决定，或者由球本身的上一个状态决定，由外部传入
    input wire[7:0] speed_curr;  
    output reg[9:0] pos_x,
    output reg[9:0] pos_y;
    output reg[9:0] pos_z;
    output reg[7:0] angle_next; //下一个时刻的角度
    output reg[7:0] speed_next; //下一个时刻的速度
    output reg[1:0] anim_stat;  //用于渲染不同的足球图标，达到“旋转”的效果 
);
    parameter speed_change_T = 1000; //每1000个周期将速度降低1 
    parameter pos_change_T = 1000;  //注意：下面的移动乘以倍率64，理论上这里的周期应该延长为本来的64倍。注意控制好数值！
    parameter anim_change_T = 1000; //每间隔1000个周期改变一次动画状态
    initial begin
        pos_x = 0;
        pos_y = 0;
        pos_z = 0;
        angle_next = 0;
        speed_next = 0;
        anim_stat = 0; //初始状态为静止
    end
    wire [11:0] speed_dec_counter = 12'b0;
    wire [11:0] pos_change_counter = 12'b0;
    wire [11:0] anim_counter = 12'b0;
    //速度衰减计数器
    always @ (posedge clk)
    begin
        if (speed_dec_counter == speed_change_T-1) begin
            speed_dec_counter <= 0; //计数器清零
            if(speed_next > 0) begin
                speed_next <= speed_curr - 1; //只在速度为正时移动   
            end else begin
                speed_next <= speed_curr;         
            end else begin
                speed_next <= speed_curr;
            end       
        end else begin
            speed_dec_counter <= speed_dec_counter + 12'b1;      //这样语法是否正确？
            speed_next <= speed_curr; //保持不变
        end    
    end
    
    //位置变化计数器
    always @ (posedge clk)
    begin
        if (pos_change_counter == pos_change_T-1) begin
            pos_change_counter <= 0; //计数器清零
            if(speed_next > 0) begin
                pos_x <= pos_x + speed_next * index2cos_mul_64(angle2index(angle_curr)); //根据角度和速度计算新的位置
                pos_y <= pos_y + speed_next * index2sin_mul_64(angle2index(angle_curr)); //根据角度和速度计算新的位置
            end else begin
                pos_x <= pos_x;
                pos_y <= pos_y;
            end    
        end else begin
            pos_change_counter <= pos_change_counter + 12'b1;
            pos_x <= pos_x;
            pos_y <= pos_y;
        end    
    end
    //动画状态计数器
    always @ (posedge clk)
    begin
        if (anim_counter == anim_change_T-1) begin
            anim_counter <= 0;
            if(anim_stat == 2'b00) begin
                anim_stat <= 2'b01; //原始自动机
            end else if(anim_stat == 2'b01) begin
                anim_stat <= 2'b10;
            end else if(anim_stat == 2'b10) begin
                anim_stat <= 2'b11;
            end else begin
                anim_stat <= 2'b00;
            end    
        end else begin
            anim_counter <= anim_counter + 12'b1; 
            anim_stat <= anim_stat; 
        end    
    end
endmodule
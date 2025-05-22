// 进行背景的切换
// 目前的小图片管理机制是： 每一个type有1000个扇区
// 支持10个类，从第10000个扇区开始作为background的存储地址，每个2MB = 4096个扇区，预留5000个扇区的位置
// 因此映射关系为： start_sector = 10000 + 5000*bg_index，换算成地址还要乘以512
module switch_bg
#(parameter BG_WIDTH=1280, BG_HEIGHT=720)
(
    input switch_bg_ui_clk,
    input ui_rst,
    // 与game controller交互
    input switch_begin,
    input [5:0] bg_index,       // 使用的场景编号，应该也有一个映射
    output reg switch_end,
    // 控制信号，和video交互
    output reg dark_begin,
    input reg dark_end,
    output light_begin,
    input light_end,
    // 与SDRAM交互的信号
    output reg[1:0] sdram_cmd,          //命令，  0无效，1读取，2写入
    output reg[29:0] operate_addr,      //地址
    output reg[63:0] write_data,
    input [63:0] read_data,
    input cmd_done,
    //与SRAM的接口
    output reg sram_io_req,        //读写请求
    output reg [19:0] times,       //读写次数
    output reg wr,                 //是否选择“写”
    output reg [19:0] addr,
    output reg [31:0] din,          // 渲染信息
    input wire [31:0] dout
);
    localparam [3:0] IDLE=0, READ1=1, READ2=2, WRITE1=3, WRITE2=4, WRITE3=5, PRE_READ=6, PRE_WRITE=7,DONE=8,
        DARK=9, LIGHT=10, REQ=11, COPY=12;
    reg [3:0] bg_stat;

    reg [19:0] block_counter;   // 256B为一个块，一共需要拷贝7200个Block （而且要向两份显存都拷贝）
    reg [7:0] req_counter;  //请求32次
    reg [7:0] copy_counter; //拷贝64次

    reg [31:0] buffer[63:0];

    always@(posedge switch_bg_ui_clk)begin
        if(ui_rst)begin
            dark_begin <= 0;
            light_end <= 0;
            block_counter <= 0;
            req_counter <= 0;
            copy_counter <= 0;
        end else begin
            if(bg_stat == IDLE)begin
                if(switch_begin)begin
                    //先计算出 operate_addr
                    //[ TODO ]自己在计算地址的时候，是否忽略了位宽没有自动扩展的情况？
                    operate_addr <= 30'd(10000 + 5000*bg_index)*512;
                    bg_stat <= DARK;
                end
            end else if(bg_stat == DARK)begin
                dark_begin <= 1;    // 发送信号，等待屏幕完全淡出才开始
                if(dark_end)begin
                    dark_begin <= 0;
                    bg_stat <= REQ;
                    block_counter <= 0;
                    req_counter <= 0;
                    copy_counter <= 0;
                end
            end else if(bg_stat == LIGHT)begin
                //将背景拷贝到两个显存区域
                //初步估计拷贝时间：60ms
            end else if(bg_stat == REQ)begin
                //向SDRAM请求数据，每次8字节，一共32次
                sdram_cmd <= 2'd1;
                
            end else if(bg_stat == COPY)begin
                //
            end
        end
    end

endmodule
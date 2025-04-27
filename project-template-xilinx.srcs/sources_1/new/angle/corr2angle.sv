// 读取存放角度信息的ROM
module corr2angle(      //坐标转角度（角度定义为0~256范围的一个整数）
    input wire [11:0] x1,
    input wire [11:0] y1,
    input wire [11:0] x2,
    input wire [11:0] y2,
    output reg [7:0] angle  // 输出角度，范围为0~255
);
    // 角度ROM
    reg [15:0] angle_rom [0:255];

    initial begin
        $readmemh("anqgle.hex", angle_rom);
    end

    //组合逻辑实现

    //注意：所有x1==x2 || y1==y2的情况需要在调用之前考虑，否则可能受ROM中的垃圾值影响
    reg [7:0] angle_index; //角度索引,0~63
    always @(*) begin
        if(x1 == x2) begin
            if(y1 > y2)
                angle = 8'd128;
            else
                angle = 8'd0;
        end else if(x1 > x2) begin
            if(y1 > y2) begin
                //第三象限
                if( (x1-x2)*64 <= (y1-y2) ) begin
                    angle = 8'd128;
                end else if( (y1-y2)*64 <= (x1-x2) ) begin
                    angle = 8'd192;
                end else begin
                    for(angle_index=0; angle_index<=63; angle_index=angle_index+1) begin
                        if( (x1-x2)*64 >= (y1-y2)*angle_rom[angle_index] && (x1-x2)*64 < (y1-y2)*angle_rom[angle_index+1] ) begin
                            angle = angle_index + 8'd128;
                            break;
                        end
                    end
                end
            end else begin
                //第四象限
                if( (x1-x2)*64 <= (y2-y1) ) begin
                    angle = 8'd0;
                end else if( (y2-y1)*64 <= (x1-x2) ) begin
                    angle = 8'd192;
                end else begin
                    for(angle_index=0; angle_index<=63; angle_index=angle_index+1) begin
                        if( (y2-y1)*64 >= (x1-x2)*angle_rom[angle_index] && (y2-y1)*64 < (x1-x2)*angle_rom[angle_index+1] ) begin
                            angle = angle_index + 8'd192;
                            break;
                        end
                    end
                end
            end
        end else begin  
            if( y1 < y2) begin
                //第一象限
                if( (x2-x1)*64 <= (y2-y1) ) begin
                    angle = 8'd0;
                end else if( (y2-y1)*64 <= (x2-x1) ) begin
                    angle = 8'd64;
                end else begin
                    for(angle_index=0; angle_index<=63; angle_index=angle_index+1) begin
                        if( (x2-x1)*64 >= (y2-y1)*angle_rom[angle_index] && (x2-x1)*64 < (y2-y1)*angle_rom[angle_index+1] ) begin
                            angle = angle_index + 8'd0;
                            break;
                        end
                    end
                end
            end else begin
                //第二象限
                if( (y1-y2)*64 <= (x2-x1) ) begin
                    angle = 8'd64;
                end else if( (x2-x1)*64 <= (y1-y2) ) begin
                    angle = 8'd128;
                end else begin
                    for(angle_index=0; angle_index<=63; angle_index=angle_index+1) begin
                        if( (y1-y2)*64 >= (x2-x1)*angle_rom[angle_index] && (y1-y2)*64 < (x2-x1)*angle_rom[angle_index+1] ) begin
                            angle = angle_index + 8'd64;
                            break;
                        end
                    end
                end
            end
        end
                

    end
    
endmodule
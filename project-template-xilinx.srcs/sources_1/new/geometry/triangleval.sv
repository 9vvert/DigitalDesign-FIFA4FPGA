// 一些关于三角函数值的操作
// 因为无法直接存储小数，因此采用定点的方法，正弦和余弦乘以256， 正切乘以16
// 
// 第一位0为正，1为负；剩余的9比特用来表示数据；另外后9位全1表示为无穷(1FF:正无穷； 3FF:负无穷)
// 

// 给定一个角度，返回处理后的角度 
// 前2个比特是象限(0-17, 18-35,36-53, 54-71)；后面
package TrianglevalLib;
    //给定一个0~17的值，返回正弦值*12
    localparam logic [9:0] SIN_TABLE [0:17] = '{
        10'd0, 10'd1, 10'd2, 10'd3, 10'd4, 10'd5,
        10'd6, 10'd7, 10'd8, 10'd8, 10'd9, 10'd10,
        10'd10, 10'd11, 10'd11, 10'd12, 10'd12, 10'd12
    };
    localparam logic [9:0] COS_TABLE [0:17] = '{
        10'd12, 10'd11, 10'd11, 10'd11, 10'd11, 10'd10,
        10'd10, 10'd9, 10'd9, 10'd8, 10'd7, 10'd6,
        10'd6, 10'd5, 10'd4, 10'd3, 10'd2, 10'd1
    };
    localparam logic [9:0] TAN_TABLE [0:17] = '{
        10'd0, 10'd1, 10'd3, 10'd4, 10'd6, 10'd7,
        10'd9, 10'd11, 10'd13, 10'd16, 10'd19, 10'd23,
        10'd28, 10'd34, 10'd44, 10'd60, 10'd90, 10'd183
    };

    function automatic [9:0] sin(
        input [7:0] ang
    );
        return SIN_TABLE[ang];
    endfunction

    function automatic [9:0] cos(
        input [7:0] ang
    );
        return COS_TABLE[ang];
    endfunction

    function automatic [9:0] tan(
        input [7:0] ang
    );
        return TAN_TABLE[ang];
    endfunction


    function automatic [7:0] arctan(
        input [15:0] y,
        input [15:0] x
    );
        reg [7:0] angle;
        begin
            if (y > x) begin  // 10-18
                if ((y<<4) <= ((x << 4) + (x << 1) + x)) begin
                    angle = 10;
                end else if ((y<<4) <= ((x << 4) + (x << 3) + (x << 2) + x)) begin
                    angle = 11;
                end else if ((y<<4) <= (x << 4) + (x << 3) + (x << 2)) begin
                    angle = 12;
                end else if ((y<<4) <= ((x << 5) + (x << 1))) begin
                    angle = 13;
                end else if ((y<<4) <= ((x << 5) + (x << 3) + (x << 2))) begin
                    angle = 14;
                end else if ((y<<4) <= ((x << 5) + (x << 4) + (x << 3) + (x << 2))) begin
                    angle = 15;
                end else if ((y<<4) <= ((x << 6) + (x << 4) + (x << 3) + (x << 1))) begin
                    angle = 16;
                end else if ((y<<4) <= ((x << 7) + (x << 5) + (x << 4) + (x << 2) + x)) begin
                    angle = 17;
                end else begin
                    angle = 18;
                end
            end else begin  // 0-9
                if ((y<<4) == 0 * x) begin
                    angle = 0;
                end else if ((y<<4) <=  x) begin
                    angle = 1;
                end else if ((y<<4) <= (x + (x<<1))) begin
                    angle = 2;
                end else if ((y<<4) <= (x<<2)) begin
                    angle = 3;
                end else if ((y<<4) <= ((x<<1) + (x<<2))) begin
                    angle = 4;
                end else if ((y<<4) <= ((x<<2) + (x<<1) + x)) begin
                    angle = 5;
                end else if ((y<<4) <= ((x<<3) + x)) begin
                    angle = 6;
                end else if ((y<<4) <= ((x<<3) + (x<<1) + x)) begin
                    angle = 7;
                end else if ((y<<4) <= (x<<3) + (x<<2) + x) begin
                    angle = 8;
                end else begin
                    angle = 9;
                end
            end
        end
        arctan = angle;
    endfunction



    // 给定A和B，返回从A到B引线的角度
    // 必须确保A和B不重合
    function automatic[7:0] vec2angle(
        input [11:0] x1,
        input [11:0] y1,
        input [11:0] x2,
        input [11:0] y2
    );
        automatic logic[11:0] delta_x = (x1 > x2) ? (x1-x2) : (x2-x1);
        automatic logic[11:0] delta_y = (y1 > y2) ? (y1-y2) : (y2-y1);
        
        if(x1 > x2) begin
            if(y1 > y2) begin
                //第三象限
                vec2angle = 8'd36 + arctan(delta_x, delta_y);   // delta_x / delta_y
            end else if(y1 < y2) begin
                //第四象限
                vec2angle = 8'd54 + arctan(delta_y, delta_x);   // delta_x / delta_y
                if(vec2angle >= 8'd72) begin        //这里有可能会算出72
                    vec2angle = vec2angle - 8'd72;
                end
            end else begin
                vec2angle = 8'd54;
            end
        end else if(x1 < x2) begin
            if(y1 > y2) begin
                //第二象限
                vec2angle = 8'd18 + arctan(delta_y, delta_x);   // delta_x / delta_y
            end else if(y1 < y2) begin
                //第一象限
                vec2angle = arctan(delta_x, delta_y);   // delta_x / delta_y
            end else begin
                vec2angle = 8'd18;
            end
        end else begin
            if(y1 > y2) begin
                vec2angle = 8'd36;
            end else if(y1 < y2)begin
                vec2angle = 8'd0; 
            end else begin
                vec2angle = 8'hFF;      // 表示0向量
            end
        end

    endfunction
endpackage
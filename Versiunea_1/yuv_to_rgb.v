module yuv_to_rgb (
input            clk             , // Ceas de sistem, acelasi ca si cel de APB
input            rst_n           , // Reset asincron, activ pe 0 logic, acelasi ca si cel de APB
input            start_conversion, // Indica inceperea conversiei cand datele YUV sunt incarcate
input      [7:0] y               , 
input      [7:0] u               ,
input      [7:0] v               ,
output reg [7:0] r               , 
output reg [7:0] g               , 
output reg [7:0] b               ,
output reg       pixel_ready       // Indica finalizarea conversiei, se pot citi valorile RGB
);

// Fixed-point coefficients (Q10 format: 10 fractional bits)
parameter signed [15:0] C_1_402 = 16'h059C;  // 1.402 * 2^10
parameter signed [15:0] C_0_344 = 16'h0160;  // 0.344 * 2^10
parameter signed [15:0] C_0_714 = 16'h02DB;  // 0.714 * 2^10
parameter signed [15:0] C_1_772 = 16'h0716;  // 1.772 * 2^10

// Intermediate signed values (16-bit for precision)
wire signed [15:0] y_s;
wire signed [15:0] u_s;
wire signed [15:0] v_s;

// Temporary results (32-bit to avoid overflow)
wire signed [31:0] r_temp;
wire signed [31:0] g_temp;
wire signed [31:0] b_temp;

assign y_s = y;
assign u_s = u - 128;  // Offset U
assign v_s = v - 128;  // Offset V

assign r_temp = y_s + ((v_s * C_1_402) >>> 10);
assign g_temp = y_s - ((u_s * C_0_344) >>> 10) - ((v_s * C_0_714) >>> 10);
assign b_temp = y_s + ((u_s * C_1_772) >>> 10);

// Clamp to 0-255
always @(posedge clk or negedge rst_n)	
	if (~rst_n)	            r <= 8'h00; else
	if (start_conversion) begin	
		if (r_temp < 'd0)	    r <= 8'h00; else
		if (r_temp > 'd255) 	r <= 8'hFF; else
											    r <= r_temp[7:0];
	end
	
always @(posedge clk or negedge rst_n)	
	if (~rst_n)	            g <= 8'h00; else
	if (start_conversion) begin	
		if (g_temp < 'd0)	    g <= 8'h00; else
		if (g_temp > 'd255) 	g <= 8'hFF; else
											    g <= g_temp[7:0];
	end
	
always @(posedge clk or negedge rst_n)	
	if (~rst_n)	            b <= 8'h00; else
	if (start_conversion) begin	
		if (b_temp < 'd0)	    b <= 8'h00; else
		if (b_temp > 'd255) 	b <= 8'hFF; else
											    b <= b_temp[7:0];
	end
	
always @(posedge clk or negedge rst_n)
	if (~rst_n)     	        pixel_ready <= 1'b0; else
	if (pixel_ready)          pixel_ready <= 1'b0; else
	if (start_conversion)	    pixel_ready <= 1'b1;


endmodule
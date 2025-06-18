module yuv_to_rgb_tb();

reg        clk             ;
reg        rst_n           ;
reg        start_conversion;
reg  [7:0] y               ;
reg  [7:0] u               ;
reg  [7:0] v               ;
wire [7:0] r               ;
wire [7:0] g               ;
wire [7:0] b               ;
wire       pixel_ready     ;

initial begin
	clk <= 1'b0; 
	forever #10 clk <= ~clk;
end

initial begin
	rst_n <= 1'b1;
	#22;
	rst_n <= 1'b0;
	#10;
	rst_n <= 1'b1;
end

initial begin
	@(negedge rst_n);
	@(posedge rst_n);
	@(posedge clk);
	yuv_transactions(8'h22, 8'h15, 8'h12);
	$finish;
end

task yuv_transactions( input reg [7:0] y_in, input reg [7:0] u_in, input reg [7:0] v_in)
	begin
		@(posedge clk);
		y <= y_in;
		u <= u_in;
		v <= v_in;
		start_conversion <= 1'b1;
		@(posedge clk);
		start_conversion <= 1'b0;
		@(posedge clk iff pixel_ready);
		$display("Valori initiale y: %h, u: %h, v: %h\n Valori finale r: %h, g: %h, b: %h\n", y, u, v, r, g, b);
	end
endtask


yuv_to_rgb yuv_to_rgb_i(
.clk               (clk             ),
.rst_n             (rst_n           ),
.start_conversion  (start_conversion),
.y                 (y               ),
.u                 (u               ),
.v                 (v               ),
.r                 (r               ), 
.g                 (g               ), 
.b                 (b               ),
.pixel_ready       (pixel_ready     )
);

endmodule
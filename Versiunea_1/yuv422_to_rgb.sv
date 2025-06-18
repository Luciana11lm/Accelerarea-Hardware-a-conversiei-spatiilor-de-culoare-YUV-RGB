module yuv422_to_rgb (
input             pclk               , // Ceas APB
input             presetn            , // Reset asincron APB, activ pe 0 logic
input      [31:0] paddr              , // Adresa de scriere/citire APB
input      [31:0] pwdata             , // 32 biti formati din 4 valori YUV = Y0 U0 Y1 V0 transmisi cand pwrite este 1
output reg [31:0] prdata             , // 32 de biti de date RGB = 8 biti R [31:24]  + 8 biti G [23:16] + 8 biti B [15:8] + 8 biti 0 [7:0]
input         	  pwrite             , // Acces APB de scriere cand este 1, acces de citire cand este 0
input         	  psel               , // Semnal de selectie a slave-ului – modulul de conversie
input         	  penable            , 
output            pslverr            , // Semnal de eroare 
output            pready             , // Semnal utilizat pentru a accepta un transfer de catre slave 
output reg        irq                , // Semnal de intrerupere pentru a marca finalizare conversiei a 4 pixeli
output reg [7:0]  rgb_out [0:3][0:2]   // Memorie pentru stocarea valorilor RGB pentru cei 4 pixeli
);

// Stari FSM
localparam IDLE    = 3'd0;
localparam LOAD    = 3'd1;
localparam CONVERT = 3'd2;

reg  [7:0] yuv_mem [0:7];    // Memorie interna pentru stocarea valorilor YUV ale celor 4 pixeli, primite pe APB
reg  [7:0] y0;               // Valoarea componentei Y pentru pixelul 0
reg  [7:0] u0;               // Valoarea componentei U pentru pixelul 0/1
reg  [7:0] y1;               // Valoarea componentei Y pentru pixelul 1
reg  [7:0] v0;               // Valoarea componentei V pentru pixelul 0/1
reg  [7:0] y2;               // Valoarea componentei Y pentru pixelul 2
reg  [7:0] u1;               // Valoarea componentei Y pentru pixelul 2/3
reg  [7:0] y3;               // Valoarea componentei Y pentru pixelul 3
reg  [7:0] v1;               // Valoarea componentei Y pentru pixelul 2/3
wire [7:0] r0;               // Valoarea componentei R pentru pixelul 0
wire [7:0] g0;               // Valoarea componentei G pentru pixelul 0
wire [7:0] b0;               // Valoarea componentei B pentru pixelul 0
wire [7:0] r1;               // Valoarea componentei R pentru pixelul 1
wire [7:0] g1;               // Valoarea componentei G pentru pixelul 1
wire [7:0] b1;               // Valoarea componentei B pentru pixelul 1
wire [7:0] r2;               // Valoarea componentei R pentru pixelul 2
wire [7:0] g2;               // Valoarea componentei G pentru pixelul 2
wire [7:0] b2;               // Valoarea componentei B pentru pixelul 2
wire [7:0] r3;               // Valoarea componentei R pentru pixelul 3
wire [7:0] g3;               // Valoarea componentei G pentru pixelul 3
wire [7:0] b3;               // Valoarea componentei B pentru pixelul 3
reg        cnt_writes;       // Counter pentru numarul de scrieri pe APB 
reg  [2:0] state;            // Inidcator stare
reg        start_conversion; // Indica inceperea conversiei dupa cele doua scrieri ale valorilor YUV pentru 4 pixeli
wire [3:0] result_ready;     // Semnal codat one-hot pentru a indica ca fiecare instanta a terminat conversia

// Instante ale modulului de conversie individuala 
yuv_to_rgb conv0 (.clk(pclk), .rst_n(presetn), .start_conversion(start_conversion), .y(y0), .u(u0), .v(v0), .r(r0), .g(g0), .b(b0), .pixel_ready(result_ready[0]));
yuv_to_rgb conv1 (.clk(pclk), .rst_n(presetn), .start_conversion(start_conversion), .y(y1), .u(u0), .v(v0), .r(r1), .g(g1), .b(b1), .pixel_ready(result_ready[1]));
yuv_to_rgb conv2 (.clk(pclk), .rst_n(presetn), .start_conversion(start_conversion), .y(y2), .u(u1), .v(v1), .r(r2), .g(g2), .b(b2), .pixel_ready(result_ready[2]));
yuv_to_rgb conv3 (.clk(pclk), .rst_n(presetn), .start_conversion(start_conversion), .y(y3), .u(u1), .v(v1), .r(r3), .g(g3), .b(b3), .pixel_ready(result_ready[3]));

//-----------------APB signals---------------

assign pready  = 1'b1;
assign pslverr = 1'b0;

always @(posedge pclk or negedge presetn)
	if (~presetn)	prdata <= 32'd0; else
	if (psel & ~penable & ~pwrite)	
		case(paddr[7:0])
			8'h20: prdata <= (state == IDLE) ? {32'hFFFFFFFF} : {32'd0};
			8'h30: prdata <= {rgb_out[0][0], rgb_out[0][1], rgb_out[0][2], 8'd0};  // Primul pixel
			8'h34: prdata <= {rgb_out[1][0], rgb_out[1][1], rgb_out[1][2], 8'd0};  // Al doilea pixel
			8'h38: prdata <= {rgb_out[2][0], rgb_out[2][1], rgb_out[2][2], 8'd0};  // Al treilea pixel
			8'h3c: prdata <= {rgb_out[3][0], rgb_out[3][1], rgb_out[3][2], 8'd0};  // Al patrulea pixel
		endcase           

//--------------------FSM---------------------	

// Counter ce se incrementeaza dupa fiecare operatie de scriere, 4 pixeli scrisi => 2 scrieri succesive => necesar 1 bit
always @(posedge pclk or negedge presetn)
	if (~presetn)	                        cnt_writes <= 'd0; else
	if (psel & penable & pready & pwrite)	cnt_writes <= cnt_writes + 'd1;

// Puls de inceperea conversiei cand s-au finalizat doua scrieri 
always @(posedge pclk or negedge presetn)
	if (~presetn)	                                     start_conversion <= 1'b0; else
	if (start_conversion)                              start_conversion <= 1'b0; else
	if (psel & penable & pready & pwrite & cnt_writes) start_conversion <= 1'b1;
	
// Puls se intrerupere la finalizarea conversiei - indicator ca datele pot fi citite
always @(posedge pclk or negedge presetn)
	if (~presetn)      	irq <= 1'b0; else
	if (irq)					  irq <= 1'b0; else
	if (&result_ready)	irq <= 1'b1;

// Flux logic FSM	
always @(posedge pclk or negedge presetn)
	if (~presetn)	                                                  state <= IDLE; else
	case(state)
		IDLE    : if (psel & ~penable & pwrite)                       state <= LOAD;    // Se incarca datele primite pe APB de la procesor
		LOAD    : if (psel & penable & pready & pwrite & cnt_writes)  state <= CONVERT; // Dupa ce s-au primit cei 4 pixeli se poate trece la conversie
		CONVERT : if (&result_ready)                                  state <= IDLE;    // Dupa primirea semanlului de data ready de la fiecare instanta de conversie, se poate trece in stare de idle
	endcase
	
// Stocare in memorie a datelor scrise - 4 valori / adresa 
always @(posedge pclk or negedge presetn)
	if (~presetn) begin	yuv_mem[0] <= 8'd0;
	                    yuv_mem[1] <= 8'd0;
	                    yuv_mem[2] <= 8'd0;
	                    yuv_mem[3] <= 8'd0;
	                    yuv_mem[4] <= 8'd0;
	                    yuv_mem[5] <= 8'd0;
	                    yuv_mem[6] <= 8'd0;
	                    yuv_mem[7] <= 8'd0; end else
	if (psel & pwrite & ~penable) 
		case (paddr[7:0])                               
      8'h10: begin yuv_mem[0] <= pwdata[7:0];          // Y0
									 yuv_mem[1] <= pwdata[15:8];         // U0
									 yuv_mem[2] <= pwdata[23:16];        // Y1
									 yuv_mem[3] <= pwdata[31:24]; end    // V0
      8'h14: begin yuv_mem[4] <= pwdata[7:0];          // Y2
                   yuv_mem[5] <= pwdata[15:8];         // U1
                   yuv_mem[6] <= pwdata[23:16];        // Y3
                   yuv_mem[7] <= pwdata[31:24]; end    // V1
    endcase
	
// Stocare in memorie a valorilor obtinute in urma conversiei
always @(posedge pclk or negedge presetn)
	if (~presetn)	begin rgb_out[0] <= {8'd0, 8'd0, 8'd0};
	                    rgb_out[1] <= {8'd0, 8'd0, 8'd0};
	                    rgb_out[2] <= {8'd0, 8'd0, 8'd0};
                      rgb_out[3] <= {8'd0, 8'd0, 8'd0}; end else
	if (&result_ready)	begin rgb_out[0] <= {r0, g0, b0};           // Se stocheaza atunci cand valorile RGB pentru toti cei 4 pixeli sunt convertite
														rgb_out[1] <= {r1, g1, b1};
														rgb_out[2] <= {r2, g2, b2};
														rgb_out[3] <= {r3, g3, b3}; end
	
// Incarcarea componentei Y0 pentru transmiterea catre instanta de conversie	
always @(posedge pclk or negedge presetn)
	if (~presetn)	                    y0 <= 'd0; else
	if ((state == LOAD) & cnt_writes) y0 <= yuv_mem[0];

// Incarcarea componentei U0 pentru transmiterea catre instanta de conversie
always @(posedge pclk or negedge presetn)
	if (~presetn)	                    u0 <= 'd0; else
	if ((state == LOAD) & cnt_writes) u0 <= yuv_mem[1];
	
// Incarcarea componentei Y1 pentru transmiterea catre instanta de conversie
always @(posedge pclk or negedge presetn)
	if (~presetn)	                    y1 <= 'd0; else
	if ((state == LOAD) & cnt_writes) y1 <= yuv_mem[2];

// Incarcarea componentei V0 pentru transmiterea catre instanta de conversie	
always @(posedge pclk or negedge presetn)
	if (~presetn)	                    v0 <= 'd0; else
	if ((state == LOAD) & cnt_writes) v0 <= yuv_mem[3];
	
// Incarcarea componentei Y2 pentru transmiterea catre instanta de conversie
always @(posedge pclk or negedge presetn)
	if (~presetn)	                    y2 <= 'd0; else
	if ((state == LOAD) & cnt_writes) y2 <= yuv_mem[4];

// Incarcarea componentei U1 pentru transmiterea catre instanta de conversie	
always @(posedge pclk or negedge presetn)
	if (~presetn)	                    u1 <= 'd0; else
	if ((state == LOAD) & cnt_writes) u1 <= yuv_mem[5];
	
// Incarcarea componentei Y3 pentru transmiterea catre instanta de conversie
always @(posedge pclk or negedge presetn)
	if (~presetn)	                    y3 <= 'd0; else
	if ((state == LOAD) & cnt_writes) y3 <= yuv_mem[6];

// Incarcarea componentei V1 pentru transmiterea catre instanta de conversie	
always @(posedge pclk or negedge presetn)
	if (~presetn)	                    v1 <= 'd0; else
	if ((state == LOAD) & cnt_writes) v1 <= yuv_mem[7];

endmodule
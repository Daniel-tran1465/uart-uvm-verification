# Verification Plan — UART Design

## 1. Mục tiêu & phạm vi

Verify chức năng của UART (Universal Asynchronous Receiver/Transmitter) bao gồm khối TX, khối RX, baud rate generator. Verification plan này là tài liệu sống — cập nhật khi RTL thay đổi hoặc phát hiện thêm case cần test.


- **Kiến trúc: UART echo/loopback tự động.** Top module `UART` chỉ có 4 port ra ngoài: `clk`, `reset`, `Rx_pin` (input), `Tx_pin` (output) — **không có port data song song (parallel data in/out) lộ ra ngoài top module**. Khi RX nhận xong 1 byte (`Rx_IRQ` = 1) và TX đang rảnh (`Tx_Ready` = 1), FSM trong `UART.sv` tự động kích `Tx_start` để gửi lại chính byte vừa nhận — tức đây là echo, không phải UART truyền/nhận độc lập hai chiều tự do.
- **Data width:** tham số hoá qua `data_width` (mặc định 8), nhưng cố định lúc compile, không đổi runtime.
- **Baud rate:** tham số hoá qua `sysclkfreq` (mặc định 50MHz) và `baudrate` (mặc định 115200), cố định lúc compile.
- **Parity: KHÔNG có.** Nhìn vào `UART_TX.sv`, gói tin chỉ là `{1'b1, Tx_Din, 1'b0}` — 1 start bit (mức 0) + N data bit + 1 stop bit (mức 1). Không có bit parity nào trong khung truyền.
- **Stop bit:** chỉ 1 bit, không cấu hình được 1.5/2.
- **Không có error flag output** (không có parity_err/framing_err) — `UART_RX` không kiểm tra tính hợp lệ của stop bit, chỉ đơn thuần đếm đủ bit rồi báo `Rx_IRQ`.
- **Không có FIFO, không có RTS/CTS.**
- **Đồng bộ ngõ vào:** `Sync.sv` là bộ đồng bộ 2 tầng flip-flop chuẩn (double-flop synchronizer) để tránh metastability trên `Rx_pin`, nhưng **đây không phải bộ lọc nhiễu (glitch filter)** — glitch ngắn 1 chu kỳ clock vẫn đi qua được, chỉ mất 2 chu kỳ trễ.

> Vì top-level chỉ có `Rx_pin`/`Tx_pin` (giao tiếp serial thuần), testbench sẽ đóng vai trò như **một thiết bị UART bên ngoài**: driver phải tự "bit-bang" (serialize) từng byte thành sóng trên `Rx_pin`, và monitor phải tự deserialize sóng trên `Tx_pin` thành byte để so sánh. Đây là điểm khác biệt lớn nhất so với plan gốc — không thể inject/đọc data song song trực tiếp.

---

### ✅ Ghi chú từ việc đọc RTL — đã fix, cần confirm lại bằng simulation

Các điểm nghi vấn dưới đây đã được sửa trực tiếp trong RTL (xem file `UART_TX.sv`, `UART_RX.sv`, `BaudClkGenerator.sv`, `ShiftRegister.sv` — mỗi chỗ sửa có comment `// FIX:`). **Trạng thái "đã fix" chỉ là sửa theo đọc code tĩnh (static review), chưa được xác nhận bằng simulation thật** — bước tiếp theo bắt buộc là chạy directed test (mục 3, F1-F3) để xác nhận các fix này thực sự giải quyết đúng vấn đề, không phát sinh lỗi mới.

1. **`UART_TX.sv`**: `Tx_bauclk` → đổi thành `Tx_baudclk`, khớp tên đang dùng ở chỗ nối `BaudClkGenerator`/`Serialiser`.
2. **`UART_RX.sv`**: `rx_sync`/`rx_sync_delayed` → đổi thành `Rx_Sync`/`Rx_Sync_delayed`, khớp tên dùng khi nối `Sync`/`ShiftRegister`. Đây là bug nghiêm trọng nhất vì nó khiến falling-edge detect không hoạt động đúng.
3. **`BaudClkGenerator.sv`**: nhánh `bitperiodcounter == bitperiod` đổi `baudclk <= 1'b0` → `baudclk <= 1'b1`, để tạo pulse báo hiệu đủ 1 bit period.
4. **`ShiftRegister.sv`**: cổng `ShiftEn` đổi từ `output` → `input`, đúng vai trò nhận tín hiệu từ `Rx_baudclk`.
5. **`UART_RX.sv`**: `next_state <= collected;` → `next_state = collected;` (blocking, đúng convention trong `always_comb`).

---

## 1b. Quy trình DV thực tế trong doanh nghiệp — và cách áp dụng cho sinh viên

Quy trình chuẩn trong công ty gồm các bước: đọc Specification → viết VPlan (review cùng Designer) → xây Verification Environment → phát triển testcase + chạy simulation → debug/root-cause → phân tích Coverage → (với ASIC) Gate-Level Simulation → Verification Signoff.

Vì là project cá nhân của sinh viên, không có Designer, không có GLS flow, không có khách hàng thật — nên áp dụng có điều chỉnh như sau:

| Bước trong công ty | Áp dụng cho project sinh viên |
|---|---|
| Đọc Design Specification | Tự viết một **mini-spec** trước khi làm VPlan: mô tả giao thức UART hoạt động ra sao, cách tính baud rate, các mode hỗ trợ, corner case dự kiến. Việc tự viết spec giúp hiểu sâu và là bằng chứng làm đúng quy trình khi phỏng vấn. |
| Review VPlan cùng Designer | Không có Designer, nên tự đóng vai phản biện: đọc lại VPlan sau vài ngày, tự hỏi "đã hiểu đúng chưa, còn thiếu case nào không". Có thể nhờ bạn học/mentor đọc góp ý — vừa cải thiện VPlan vừa là kỹ năng collaboration đáng ghi trong CV. |
| Debug & root-cause analysis | Khi testcase FAIL, **không mặc định RTL sai** — có thể do testcase viết sai, monitor thu sai timing, scoreboard so sánh nhầm, hoặc do hiểu sai đặc tả. Ghi lại quá trình debug (không chỉ kết quả) vào mục 8 bên dưới — đây là phần gây ấn tượng nhất khi phỏng vấn, vì thể hiện tư duy debug thật chứ không chỉ "code chạy pass". |
| Gate-Level Simulation (GLS) | Không cần làm ở cấp sinh viên (cần luồng synthesis + netlist). Nhưng nên **biết và giải thích được** trong phỏng vấn: project dừng ở RTL-level verification, và hiểu rằng dự án thật còn có GLS để bắt X-propagation, khởi tạo tín hiệu thiếu, vấn đề reset sequence liên quan timing. |
| Verification Signoff | Doanh nghiệp dùng tiêu chí cứng (90% statement, 85% branch, 100% functional coverage...). Sinh viên nên **tự đặt mục tiêu số cụ thể cho project của mình** (xem mục 6) và tự đánh giá đạt bao nhiêu % — quan trọng là có mục tiêu rõ ràng và biết mình đứng ở đâu, không nhất thiết phải chạm đúng con số doanh nghiệp. |

---

## 2. Feature List (những gì cần verify)

| ID | Feature | Mô tả |
|----|---------|-------|
| F1 | RX basic frame | Nhận đúng 1 byte hợp lệ trên `Rx_pin`: start bit(0) → N data bit (LSB first) → stop bit(1), `Rx_IRQ` được set đúng lúc |
| F2 | TX basic frame | `UART_TX` phát đúng gói `{stop=1, data, start=0}` ra `Tx_Dout` khi `Tx_start` được kích |
| F3 | Echo end-to-end | Toàn hệ thống: byte gửi vào `Rx_pin` → sau độ trễ hợp lý, byte y hệt xuất hiện trên `Tx_pin` |
| F4 | Baud rate generator timing | `baudclk`/`Ready` sinh đúng thời điểm theo `bitperiod` tính từ `sysclkfreq`/`baudrate` |
| F5 | Data width parameter | Đổi `data_width` (compile-time) vẫn hoạt động đúng — test với vài giá trị khác 8 nếu cần |
| F6 | Corner-case data | Data toàn 0x00, toàn 0xFF, xen kẽ 0x55/0xAA |
| F7 | Back-to-back frame (RX) | Nhiều byte gửi liên tiếp vào `Rx_pin`, mỗi byte đều được `Rx_IRQ` đúng, không bị mất/lệch frame |
| F8 | Echo timing khi RX liên tục | Vì kiến trúc echo cần `Tx_Ready`=1 mới echo được — kiểm tra khi RX nhận byte mới trong lúc TX đang bận gửi echo byte trước, hành vi có đúng như kỳ vọng (drop, chờ, hay overwrite `Rx_data`?) |
| F9 | Reset giữa chừng | Assert `reset` khi đang giữa khung RX hoặc TX, hệ thống phải quay lại `idle` sạch, không kẹt trạng thái |
| F10 | Glitch trên `Rx_pin` | Glitch ngắn (1 chu kỳ clock) trước start bit thật — vì `Sync` chỉ đồng bộ chứ không lọc nhiễu, cần xác nhận RTL có tự chống được false-trigger hay không (đây là **giới hạn đã biết của thiết kế**, không phải bug — ghi rõ trong report) |
| F11 | Baud rate mismatch (nguồn ngoài) | Nếu testbench đóng vai "thiết bị ngoài" gửi với baud hơi lệch so với `baudrate` cấu hình sẵn của DUT, RX có còn decode đúng trong dung sai cho phép không |
| F12 | Confirm RTL fixes qua simulation | 5 bug tìm được qua static review (mục "Ghi chú từ đọc RTL") cần được xác nhận lại bằng simulation thật — chạy F1-F3 và xem waveform để đảm bảo fix đúng, không phát sinh lỗi mới |

> Đã bỏ các mục Parity, Framing/Parity error detection, FIFO, RTS/CTS so với bản plan gốc — vì thiết kế thật của cậu **không có** các phần này. Nếu sau này cậu mở rộng RTL thêm các phần đó, quay lại thêm feature tương ứng.

---

## 3. Test Plan chi tiết (traceability: Feature → Test → Coverage)

### 3.1 RX (đưa byte vào qua `Rx_pin`)

| Test case | Mục tiêu | Coverage item liên quan |
|---|---|---|
| rx_basic_frame_test | Bit-bang 1 byte hợp lệ vào `Rx_pin`, check `Rx_IRQ` set đúng lúc và `Rx_Dout`/`Rx_data` đúng giá trị | cp_rx_data |
| rx_corner_data_test | Data 0x00, 0xFF, 0x55, 0xAA | cp_rx_data (bin đặc biệt) |
| rx_back_to_back_test | Nhiều byte liên tiếp không nghỉ giữa các frame trên `Rx_pin` | cp_rx_gap |
| rx_glitch_test | Glitch 1 chu kỳ clock trước start bit thật — ghi nhận kết quả (đây là giới hạn thiết kế đã biết, không phải fail bắt buộc) | cp_rx_glitch |
| rx_reset_mid_frame_test | Assert reset khi đang giữa chừng nhận 1 byte | cp_rx_reset_timing |

### 3.2 TX (module con, test độc lập trước khi tích hợp)

| Test case | Mục tiêu | Coverage item liên quan |
|---|---|---|
| tx_basic_frame_test | Kích `Tx_start` với `Tx_Din` cụ thể, check waveform `Tx_Dout` đúng thứ tự start/data/stop | cp_tx_data |
| tx_corner_data_test | Data 0x00, 0xFF, 0x55, 0xAA | cp_tx_data |
| tx_reset_mid_transmission_test | Assert reset khi đang gửi dở | cp_tx_reset_timing |

> Vì `UART_TX`/`UART_RX` là module con có port song song riêng (`Tx_Din`, `Rx_Dout`...), cậu có thể test 2 module này **độc lập ở mức unit** (instantiate riêng `UART_TX`/`UART_RX`, không qua top `UART`) trước khi test top-level qua `Rx_pin`/`Tx_pin`. Cách này giúp cô lập lỗi rất tốt — nếu unit-level pass mà top-level fail thì nghi ngờ đổ dồn vào FSM echo trong `UART.sv`.

### 3.3 Baud Rate Generator (unit test riêng `BaudClkGenerator`)

| Test case | Mục tiêu | Coverage item liên quan |
|---|---|---|
| baud_gen_pulse_timing_test | Kích `start`, đo khoảng cách giữa các xung `baudclk` có đúng `bitperiod` chu kỳ `clk` không — **đặc biệt kiểm tra `baudclk` có thực sự lên mức 1 ở đâu không**, vì đọc RTL nghi ngờ nó luôn ở mức 0 (xem ghi chú RTL phía trên) | cp_baud_pulse_count |
| baud_gen_ready_timing_test | Check `Ready` được set đúng sau khi đủ số pulse bằng `Data_width` | cp_baud_ready |

### 3.4 Integration — Echo end-to-end (qua top `UART`)

| Test case | Mục tiêu | Coverage item liên quan |
|---|---|---|
| echo_random_test | Bit-bang N byte random vào `Rx_pin`, monitor tự deserialize `Tx_pin`, scoreboard so sánh byte nhận được có đúng echo lại byte đã gửi | cross cp_sent_data × cp_echoed_data |
| echo_back_to_back_test | Gửi liên tục nhiều byte, kiểm tra hành vi khi byte mới tới trong lúc TX đang bận echo byte cũ (xem F8) | cp_echo_busy_overlap |
| echo_stress_test | Random liên tục vài trăm-nghìn byte, đo coverage tổng | full coverage sweep |

---

## 4. Functional Coverage Model (covergroup phác thảo)

```systemverilog
// Đặt trong monitor của RX side (lấy mẫu khi Rx_IRQ được set)
covergroup cg_uart_rx @(posedge clk iff rx_irq_sampled);
  cp_rx_data: coverpoint rx_data_captured {
    bins zero      = {8'h00};
    bins all_ones  = {8'hFF};
    bins alt1      = {8'h55};
    bins alt2      = {8'hAA};
    bins others[8] = {[8'h01:8'hFE]};
  }
  cp_rx_gap: coverpoint frame_gap_cycles {
    bins back_to_back = {0};
    bins small_gap    = {[1:10]};
    bins large_gap    = {[11:$]};
  }
endgroup

// Đặt trong monitor của TX/echo side (lấy mẫu khi byte echo hoàn tất trên Tx_pin)
covergroup cg_uart_echo @(posedge clk iff echo_frame_done);
  cp_echoed_data: coverpoint echoed_data_captured {
    bins zero      = {8'h00};
    bins all_ones  = {8'hFF};
    bins others[8] = {[8'h01:8'hFE]};
  }
  cp_echo_busy_overlap: coverpoint new_byte_during_tx_busy {
    bins hit  = {1};
    bins miss = {0};
  }
endgroup

// Cross coverage bắt buộc: xác nhận dữ liệu gửi vào và dữ liệu echo ra khớp nhau
// đặt trong scoreboard/subscriber tổng, không phải trong covergroup riêng lẻ ở trên
```

> Đây chỉ là khung sườn — cậu cần điền lại tên signal đúng theo cách driver/monitor của cậu đặt tên biến, và cross-check dữ liệu gửi vs dữ liệu echo trong scoreboard chứ không chỉ trong coverage.

---

## 5. Testbench Architecture (UVM)

Vì top-level chỉ có `Rx_pin`/`Tx_pin` (serial), kiến trúc cần một **driver đóng vai "thiết bị UART ngoài" gửi dữ liệu** và một **monitor đóng vai "thiết bị UART ngoài" nhận dữ liệu** — cả hai đều tự làm việc serialize/deserialize, không có sẵn port song song ở top để bắt/bơm trực tiếp.

```
uart_env
├── uart_agent (active)
│   ├── uart_sequencer       (sinh byte cần gửi)
│   ├── uart_driver           (serialize byte → bit-bang ra Rx_pin đúng timing baud)
│   └── uart_rx_side_monitor  (không dùng nếu chỉ có 1 agent — xem dưới)
├── uart_tx_monitor            (deserialize Tx_pin → byte, để scoreboard so sánh với byte đã gửi)
├── uart_scoreboard             (so sánh byte gửi vs byte echo về, dùng reference model = identity function)
├── uart_coverage_collector
└── uart_virtual_sequencer (nếu cần đồng bộ TX+RX trong loopback test)
```

**Reference model:** một class SystemVerilog đơn giản mô phỏng logic UART (không cần cycle-accurate, chỉ cần đúng logic) để scoreboard so sánh.

---

## 6. Sign-off Criteria

**Tiêu chí doanh nghiệp (tham khảo, không bắt buộc đạt đúng với project sinh viên):**

| Hạng mục | Ngưỡng mục tiêu |
|---|---|
| Code coverage — statement | ≥ 90% |
| Code coverage — branch | ≥ 85% |
| Functional coverage | 100% hoặc waive có lý do ghi rõ |
| SVA assertions | 100% pass, không có assertion bị disable vô lý |
| Bug nghiêm trọng còn mở | 0 |
| Regression | Pass ổn định qua ≥ 3 lần chạy liên tiếp (không flaky) |

**Tiêu chí cho project sinh viên (điền số mục tiêu của riêng cậu trước khi bắt đầu, rồi tự đánh giá đạt bao nhiêu khi xong):**

| Hạng mục | Mục tiêu tự đặt | Đạt được (điền sau) |
|---|---|---|
| Code coverage — statement | ___ % | |
| Functional coverage | ___ % | |
| Số bug nghiêm trọng đã fix | ___ | |
| Số test case đã viết | ___ | |

**Exclusion policy:** bất kỳ phần code/coverage nào không đạt phải có comment giải thích lý do (unreachable, redundant, out-of-scope) — không được bỏ qua âm thầm. Quan trọng với sinh viên: có mục tiêu rõ ràng và biết mình đứng ở đâu quan trọng hơn việc chạm đúng con số doanh nghiệp.

---

## 7. Việc cần làm ngay khi RTL xong

1. Viết reference model trước (logic thuần, không timing-accurate)
2. Build interface + basic driver/monitor cho TX, chạy test F1 để xác nhận testbench hoạt động
3. Build RX side, loopback test cơ bản (F1+F2)
4. Thêm coverage collector, chạy vài trăm random frame, xem coverage report đầu tiên
5. Từ coverage report, lấp các bin còn thiếu bằng constraint có chủ đích hoặc directed test
6. Thêm error injection (F7-F9, F15) — phần này thường là chỗ có bug nhất, ghi log lại bug tìm được
7. Viết SVA song song để bắt protocol violation ở mức thấp hơn scoreboard
8. Review lại toàn bộ, đối chiếu với bảng sign-off criteria ở mục 6

---

## 8. Debug Log — root cause, không chỉ kết quả

Khi test FAIL, đừng vội sửa RTL. Ghi lại theo mẫu này để có tư liệu thật cho phỏng vấn/CV — vì nguồn gốc lỗi có thể là RTL, testcase, monitor, scoreboard, hoặc do hiểu sai spec, không phải lúc nào cũng là RTL sai:

| # | Test bị fail | Triệu chứng | Nghi ngờ ban đầu | Root cause thực sự | Cách fix |
|---|---|---|---|---|---|
| 1 | *(static code review, chưa chạy sim)* | `Tx_baudclk` không được `BaudClkGenerator` lái vào `Serialiser` | Đọc code thấy 2 tên biến khác nhau (`Tx_bauclk` khai báo vs `Tx_baudclk` dùng) | Lỗi chính tả khi đặt tên biến, tạo ra implicit net không được nối đúng | Đổi khai báo thành `Tx_baudclk` cho khớp |
| 2 | *(static code review, chưa chạy sim)* | Falling-edge detect trên RX line không hoạt động | Đọc code thấy biến `rx_sync` dùng trong always_ff nhưng không có driver nào gán nó | Lỗi chính tả hoa/thường (`rx_sync` vs `Rx_Sync`), biến thật sự mang tín hiệu đồng bộ nằm ở tên khác | Thống nhất tên `Rx_Sync` xuyên suốt |
| 3 | *(static code review, chưa chạy sim)* | `baudclk` không bao giờ lên mức 1 | Nghi ngờ thiếu logic set mức 1 khi đủ 1 bit period | Đúng — nhánh gán `baudclk<=1'b0` thay vì `1'b1` khi `bitperiodcounter==bitperiod` | Đổi thành `baudclk <= 1'b1` ở nhánh đó |
| 4 | *(static code review, chưa chạy sim)* | Nghi ngờ xung đột driver trên `Rx_baudclk` | `ShiftEn` khai báo `output` nhưng bị nối như input từ bên ngoài | Sai chiều port trong khai báo module `ShiftRegister` | Đổi `ShiftEn` từ `output` sang `input` |
| 5 | | | | | |

> **Lưu ý quan trọng:** 4 dòng đầu được phát hiện qua đọc code tĩnh (static review), không phải qua chạy simulation thật — đây là cách hợp lệ để tìm bug (thực tế công ty cũng làm code review trước khi verify), nhưng **chưa được xác nhận bằng test thật**. Sau khi chạy directed test (mục 3, F1-F3), cậu cần cập nhật lại: nếu test pass đúng như kỳ vọng thì coi như đã confirm; nếu vẫn fail, thêm dòng mới ghi rõ triệu chứng thực tế quan sát được từ waveform/log.

---

*Ghi chú: các bin coverage, giá trị %, và feature list cần điều chỉnh lại theo RTL thực tế của cậu. Tài liệu này là điểm khởi đầu, không phải bản cuối.*

**PING-PONG CONTROL EXPLANATION**
So, we have [1:0] current_bank registers. Each of the bit represents the state of each bank. When the value == 1, it means the bank is writing, while 0 means the bank is reading. For example, the default value for this register at reset is 2'b01. This means bank[0] is writing and bank[1] is reading.
We have another register called [1:0] writing_phase. This register indicates north and west state while writing (value 1 means writing). The default value at reset for this register is 2'b11 (Why? We will see after this). This register SOLELY DETERMNIES the state of the current_bank register because we have designed the system to be underflow (Tx > Ty) so we need to STARVE the bank a.k.a the reading is already done before writing. The value to determine current_bank register using writing_phase is:
                current_bank     <= {~writing_phase[1], writing_phase[0]};

Another register called [1:0] reading_phase indicates whether the bank is valid to read or not. Its default value is 2'b01 where 1 indicates it is valid to read while the others not. 
Here's how it's works:

C = current_bank, R = reading_phase, W = writing_phase = 

Cycle 0:   C = 01, R = 01, W = 11
        -> C = 01, R = 01, W = 00 ===> Write, read does not happen for the first time
        -> C = 10, R = 01, W = 00 ===> Change current_bank

Cycle 1:   C = 10, R = 01, W = 00
        -> C = 10, R = 10, W = 00 ===> Read done first
        -> C = 10, R = 10, W = 11 ===> Write
        -> C = 01, R = 10, W = 11 ===> Change current_bank

Cycle 3:   C = 01, R = 10, W = 11
        -> C = 01, R = 01, W = 11 ===> Read done first
        -> C = 01, R = 01, W = 00 ===> Write
        -> C = 10, R = 01, W = 00 ===> Change current_bank

And so on...
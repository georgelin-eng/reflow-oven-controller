/* ******************
A C program used to implement temperature control using an FSM with ON/OFF control then port over to ARM v7

Referenced from: 
https://stackoverflow.com/questions/1371460/state-machines-tutorials/1371654#1371654
https://www.x-toaster.com/resources/basics-on-reflow-soldering/
http://www.brunel.ac.uk/~emstaam/material/bit/Finite%20State%20Machine%20with%20Arduino%20Lab%203.pdf
https://www.rfmw.com/data/mwt_solder_flow_recommendations_sn63%20.pdf

Inputs:
    @ reflow_temps - set by user from the UI
    @ temperature  - temperature value from temp_converter.c (would be temp_converter.asm when implemented in ARM)
Ouputs: 
    @ ouptut - control signal to the SSR through PWM


 *******************/

// State functions
int* ovenPower;

void do_preheat       (int* ovenPower, int temp );
void do_soak          (int* ovenPower, int temp );
void do_reflow        (int* ovenPower, int temp );
void do_cool          (int* ovenPower, int temp );

// Reflow oven controller FSM states
#define DEBUG          -1
#define STATE_ENTRY     0
#define STATE_PREHEAT   1
#define STATE_SOAK      2
#define STATE_REFLOW    3
#define STATE_COOL      4
#define STATE_EXIT      5

// Reflow solder temps array that's set by the user while in the UI state

void check_transition (int* fsm_state, int temp, int time) {
    switch (*fsm_state)
        {
        case STATE_ENTRY:
            *fsm_state = STATE_PREHEAT;
            break;
        case STATE_PREHEAT:
            if (temp > 125 && time > 60) *fsm_state = STATE_SOAK;
            break;
        case STATE_SOAK:
            if (temp > 180 && time > 200) *fsm_state = STATE_REFLOW;
            break;
        case STATE_REFLOW:
            if (temp > 200 && time > 250) *fsm_state = STATE_COOL;
            break;
        case STATE_COOL:
            *fsm_state = STATE_EXIT;
            break;
        case STATE_EXIT:
            break;
        
        default:
            break;
        }
}

int ovenPower_to_PWM (int ovenPower) {


    return -1;
}

int main () {
    int fsm_state = STATE_ENTRY; // our state variable
    int temp;                    // temperature that
    int ovenPower;               // controls the output oven power
    int time;

    while (fsm_state != STATE_EXIT) {
        
        switch (fsm_state)
        {
        case STATE_ENTRY:
            check_transition (fsm_state, temp, time);
            break;
        case STATE_PREHEAT:
            check_transition (fsm_state, temp, time);
            do_preheat       (ovenPower, temp);
            break;
        case STATE_SOAK:
            check_transition (fsm_state, temp, time);
            do_soak          (ovenPower, temp);
            break;
        case STATE_REFLOW:
            check_transition (fsm_state, temp, time);
            do_reflow        (ovenPower, temp);
            break;
        case STATE_COOL:
            check_transition (fsm_state, temp, time);
            do_cool          (ovenPower, temp);
            break;
        case STATE_EXIT:
            break;
        
        default:
            break;
        }
    }
}

void do_preheat (int* ovenPower, int temp ) {
    if (temp < 100) 
        *ovenPower = 100;
    else 
        *ovenPower = 70;
}

void do_soak (int* ovenPower, int temp ) {
    *ovenPower = 70;
}

void do_reflow (int* ovenPower, int temp ) {
    if (temp < 210)
        *ovenPower = 80;
    else
        *ovenPower = 40;
}

void do_cool (int* ovenPower, int temp ) {
    *ovenPower = 0;
}
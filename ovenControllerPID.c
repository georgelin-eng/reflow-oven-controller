/* ******************

    A C program used to implement temperature through PID then later ported over to ARM

 *******************/

/* constants for PID */
#include <stdio.h>
#include <stdlib.h>


const float Kp = 0.01;
const float Ki = 0.01;
const float Kd = 0.001;
const int   Set_Point = 353;




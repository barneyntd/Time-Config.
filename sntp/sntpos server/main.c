//
//  main.c
//  sntpos server
//
//  Created by Barney Hilken on 07/03/2024.
//

#include <stdio.h>
#include <sys/time.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <termios.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netdb.h>

#define LIVM(block) ((uint8_t *)block)[0]
#define Stratum(block) ((uint8_t *)block)[1]
#define Poll(block) ((uint8_t *)block)[2]
#define Precision(block) ((uint8_t *)block)[3]
#define RootDelay(block) ((uint32_t *)block)[1]
#define RootDisp(block) ((uint32_t *)block)[2]
#define RefID(block) ((uint32_t *)block)[3]
#define RefTime(block) ((uint64_t *)block)[2]
#define OrgTime(block) ((uint64_t *)block)[3]
#define RecvTime(block) ((uint64_t *)block)[4]
#define XmtTime(block) ((uint64_t *)block)[5]



uint64_t getNtpTime()
{
    struct timeval now;
    uint32_t sec,frac;
    
    gettimeofday(&now,NULL);
    sec = (uint32_t)now.tv_sec + 2208988800U;
    frac = (uint32_t)now.tv_usec * 4295U;
    return (uint64_t)sec << 32 | (uint64_t)frac;
}

void dump(uint8_t bytes[48])
{
    for(int i=0;i<48;i++)
    {
        fprintf(stderr, "%4.2X",bytes[i]);
        if (i%8 == 7)
            fprintf(stderr, "\n");
    }
}

int openSerial(char* device, int speed)
{
    struct termios terminal;
    int serial = open(device, O_RDWR | O_NOCTTY | O_NDELAY);
    if (serial == -1) return -1;
 
    tcflush(serial, TCIOFLUSH);

    tcgetattr(serial, &terminal);
    terminal.c_cflag |= CLOCAL | CREAD; // | CCTS_OFLOW | CRTS_IFLOW;
    terminal.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    terminal.c_oflag &= ~OPOST;
    cfsetspeed(&terminal, speed);
    tcsetattr(serial, TCSANOW, &terminal);
    fcntl(serial,F_SETFL,0);
    return serial;
}

int openSntp(char* server)
{
    int sockNum;
    struct addrinfo hints, *address;
    int error;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;

    // look up server IP address
    error = getaddrinfo(server, "123", &hints, &address);
    if (error)
    {
        fprintf(stderr, "Can't find server %d\n", error);
        return -1;
    }

    // Create socket:
    sockNum = socket(address->ai_family, SOCK_DGRAM, IPPROTO_UDP);
    if(sockNum < 0)
    {
        fprintf(stderr, "Can't create socket %d\n",errno);
        return -1;
    }
    
    // Set socket address:
    if(connect(sockNum, address->ai_addr, address->ai_addrlen))
    {
        fprintf(stderr, "Can't connect to server %d\n", errno);
        return -1;
    }
    
    freeaddrinfo(address);
    return sockNum;
}

int64_t sntp(int sockNum, uint8_t queryBlock[], uint8_t replyBlock[])
{
    uint64_t sendTime = getNtpTime(), recvTime;

    // Send the message to server:
    if(send(sockNum, queryBlock, 48, 0) < 48)
    {
        fprintf(stderr, "Unable to send query %d\n",errno);
        return INT64_MIN;
    }
    
    // Receive the server's response:
    if(recvfrom(sockNum, replyBlock, 48, 0, NULL, 0) < 48)
    {
        fprintf(stderr, "Unable to receive reply %d\n", errno);
        return INT64_MIN;
    }
    
    recvTime = getNtpTime();
    return ((int64_t)(ntohll(RecvTime(replyBlock)) - sendTime) - (int64_t)(recvTime - ntohll(XmtTime(replyBlock)))) /2;
}

int main(int argc, char * argv[])
{
    
    int serial, sock = -1;
    char *server = "pool.ntp.org";
    char opt;
    int speed = 9600;
    int local = 0;
    int interval = 24*60*60;
    int64_t correction = 0;
    uint64_t lastCheck = 0;
#ifdef DEBUG
    int debug = 2;
#else
    int debug = 1;
#endif

    while((opt = getopt(argc, argv, "s:b:d:t:l")) != -1)
        switch(opt)
        {
            case 's':
            {
                server = optarg;
                break;
            }
            case 'b':
            {
                speed = atoi(optarg);
                break;
            }
            case 'd':
            {
                debug = atoi(optarg);
                break;
            }
            case 't':
            {
                interval = atoi(optarg);
                break;
            }
            case 'l':
            {
                local = 1;
                break;
            }
        }

    if (!argv[optind])
    {
        fprintf(stderr, "Usage: %s [-sbdtl] <tty>\n",argv[0]);
        return -1;
    }

    serial = openSerial(argv[optind], speed);
    if (serial == -1) return -1;

    if (!local)
    {
        sock = openSntp(server);
        if (sock == -1) return -1;
    }

    uint8_t replyBlock[48] = {0};
    if (local)
    {
        LIVM(replyBlock) = 4<<3 | 4;                    // LI = 0, VN = 4, Mode = 4
        Stratum(replyBlock) = 4;                        // kind of random
        RefTime(replyBlock) = htonll(getNtpTime());     // set reference time to now
    }
    
    while(1)
    {
        uint8_t queryBlock[48];
        int count = 0;
        uint64_t dstTime;
        
        if (debug) fprintf(stderr, "Awaiting query\n");
        do
        {
            ssize_t chars = read(serial,queryBlock+count,48-count);
            if (chars == -1) return -2;
            count += chars;
        }
        while (count < 48);
        dstTime = getNtpTime();
        if (debug)
        {
            fprintf(stderr, "Received query data\n");
            if (debug>=2) dump((uint8_t *)queryBlock);
        }
        
        // calculate reply
        if (!local && dstTime > lastCheck + ((uint64_t)interval << 32))
        {
            if (debug) fprintf(stderr, "Forwarding to server\n");
            correction = sntp(sock, queryBlock, replyBlock);
            if (correction == INT64_MIN)
                return -1;
            if (debug)
            {
                fprintf(stderr, "Received reply data\n");
                if (debug>=2) dump((uint8_t *)replyBlock);
                fprintf(stderr, "Correction %f\n", correction / 4.2949673E9);
            }
            lastCheck = dstTime;
            Stratum(replyBlock) += 1;                           // increment stratum
        }
        else
        {
            OrgTime(replyBlock) = XmtTime(queryBlock);
            RecvTime(replyBlock) = htonll(dstTime + correction);
            XmtTime(replyBlock) = htonll(getNtpTime() + correction);
        }

        if(write(serial,replyBlock,48) != 48)
            return(-3);
        if (debug)
        {
            fprintf(stderr, "Reply sent\n");
            if (debug >= 2) dump(replyBlock);
        }
    }
    return 0;
}




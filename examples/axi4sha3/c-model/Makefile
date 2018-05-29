MODEL = 64

all: libsha3.a

libsha3.a: round.o keccak_f.o sponge.o
	ar r $@ $^

round.o: round.c
	gcc -m$(MODEL) -c -fPIC round.c -std=c99 -Wall

keccak_f.o: keccak_f.c
	gcc -m$(MODEL) -c -fPIC keccak_f.c -std=c99 -Wall

sponge.o: sponge.c
	gcc -m$(MODEL) -c -fPIC sponge.c -std=c99 -Wall

clean:
	rm -rf *o libsha3.a

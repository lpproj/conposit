# makefile for wmake (bundled with OpenWatcom)

.erase

RM_F=rm -f
CP=cp

O=obj
X=.exe

!ifdef __UNIX__
D=/
!else
D=\

!endif


AS=nasm
AFLAGS=-f obj
#AFLAGS=-f obj -l $*.lst

NKF=nkf
NKF_TOSJ=$(NKF) -s -Lw


# directives and options for wlink:
# format dos    MS-DOS EXE
# op quiet      do not show the opening message
# op caseexact  do not ignore the case of symbols
# op stack=128  stack size (256 bytes)
# disable 1172  do not show the message "W1172: stack size is less than 512 bytes"
LD=*wlink
LDFLAGS=op quiet format dos op caseexact op stack=256 disable 1172
#LDFLAGS=op quiet format dos op caseexact

.SUFFIXES:
.SUFFIXES: .sys .exe .$(O) .asm .c

.asm.$(O):
	$(AS) $(AFLAGS) -o $@ $<


all: conposit.exe conpos_n.exe READMEsj.txt

clean:
	-$(RM_F) conposit.exe conposit.$(O)
	-$(RM_F) conpos_n.exe conpos_n.$(O)
	-$(RM_F) READMEsj.txt nkf.out
	-$(RM_F) *.err *.lst
	@%quit	# return without error

conposit.exe : conposit.$(O)
	$(LD) $(LDFLAGS) name $@ file { $< }

conpos_n.exe : conpos_n.$(O)
	$(LD) $(LDFLAGS) name $@ file { $< }

conpos_n.$(O) : conposit.asm
	$(AS) $(AFLAGS) -DNEC98 -o $@ $<

READMEsj.txt : READMEja.md
	$(NKF_TOSJ) -O $< $@


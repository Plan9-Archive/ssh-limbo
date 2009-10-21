implement Sshlib;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "env.m";
	env: Env;
include "string.m";
	str: String;
include "security.m";
	random: Random;
include "keyring.m";
	kr: Keyring;
	IPint, RSAsk, RSApk, RSAsig, DSAsk, DSApk, DSAsig, DigestState: import kr;
include "factotum.m";
	fact: Factotum;
include "encoding.m";
	base16, base64: Encoding;
include "util0.m";
	util: Util0;
	prefix, suffix, rev, l2a, max, min, warn, join, eq, g32i, g64, p32, p32i, p64: import util;
include "sshfmt.m";
	sshfmt: Sshfmt;
	Val: import sshfmt;
	Tbyte, Tbool, Tint, Tbig, Tnames, Tstr, Tmpint: import sshfmt;
	valbool, valbyte, valint, valbig, valmpint, valnames, valstr, valbytes, valbuf: import sshfmt;
include "sshlib.m";


Padmin:	con 4;
Packetunitmin:	con 8;
Payloadmax:	con 32*1024; # minimum max payload size, from rfc
Pktlenmin:	con 16;
Pktlenmax:	con 35000;  # from ssh rfc

Dhexchangemin:	con 1*1024;
Dhexchangewant:	con 1*1024;  # 2*1024 is recommended, but it is too slow
Dhexchangemax:	con 8*1024;

Seqmax:	con big 2**32;

dhgroup1, dhgroup14: ref Dh;

# what we support.  these arrays are index by types in sshlib.m, keep them in sync!
knownkex := array[] of {
	"diffie-hellman-group1-sha1",
	"diffie-hellman-group14-sha1",
	"diffie-hellman-group-exchange-sha1",
};
knownhostkey := array[] of {
	"ssh-dss",
	"ssh-rsa",
};
knownenc := array[] of {
	"none",
	"aes128-cbc",
	"aes192-cbc",
	"aes256-cbc",
	"idea-cbc",  # untested
	"arcfour",
	"aes128-ctr",
	"aes192-ctr",
	"aes256-ctr",
	"arcfour128",
	"arcfour256",
	"3des-cbc",
	# "blowfish-cbc",  # doesn't work
};
knownmac := array[] of {
	"none",
	"hmac-sha1",
	"hmac-sha1-96",
	"hmac-md5",
	"hmac-md5-96",
};
knowncompr := array[] of {
	"none",
};
knownauthmeth := array[] of {
	"publickey",
	"password",
};

# what we want to do by default, first is preferred
defkex :=	array[] of {Dgroupexchange, Dgroup14, Dgroup1};
defhostkey :=	array[] of {Hrsa, Hdss};
defenc :=	array[] of {Eaes128cbc, Eaes192cbc, Eaes256cbc, Eaes128ctr, Eaes192ctr, Eaes256ctr, Earcfour128, Earcfour256, Earcfour, E3descbc};
defmac :=	array[] of {Msha1_96, Msha1, Mmd5, Mmd5_96};
defcompr :=	array[] of {Cnone};
defauthmeth :=	array[] of {Apublickey, Apassword};

msgnames := array[] of {
SSH_MSG_DISCONNECT		=> "disconnect",
SSH_MSG_IGNORE			=> "ignore",
SSH_MSG_UNIMPLEMENTED		=> "unimplemented",
SSH_MSG_DEBUG			=> "debug",
SSH_MSG_SERVICE_REQUEST		=> "service request",
SSH_MSG_SERVICE_ACCEPT		=> "service accept",
SSH_MSG_KEXINIT			=> "kex init",
SSH_MSG_NEWKEYS			=> "new keys",

SSH_MSG_KEXDH_INIT		=> "kexdh init",
SSH_MSG_KEXDH_REPLY		=> "kexdh reply",
SSH_MSG_KEXDH_GEX_INIT		=> "kexdh gex init",
SSH_MSG_KEXDH_GEX_REPLY		=> "kexdh gex reply",
SSH_MSG_KEXDH_GEX_REQUEST	=> "kexdh gex request",

SSH_MSG_USERAUTH_REQUEST	=> "userauth request",
SSH_MSG_USERAUTH_FAILURE	=> "userauth failure",
SSH_MSG_USERAUTH_SUCCESS	=> "userauth success",
SSH_MSG_USERAUTH_BANNER		=> "userauth banner",

SSH_MSG_GLOBAL_REQUEST		=> "global request",
SSH_MSG_REQUEST_SUCCESS		=> "request success",
SSH_MSG_REQUEST_FAILURE		=> "request failure",
SSH_MSG_CHANNEL_OPEN		=> "channel open",
SSH_MSG_CHANNEL_OPEN_CONFIRMATION	=> "channel open confirmation",
SSH_MSG_CHANNEL_OPEN_FAILURE	=> "open failure",
SSH_MSG_CHANNEL_WINDOW_ADJUST	=> "window adjust",
SSH_MSG_CHANNEL_DATA		=> "channel data",
SSH_MSG_CHANNEL_EXTENDED_DATA	=> "channel extended data",
SSH_MSG_CHANNEL_EOF		=> "channel eof",
SSH_MSG_CHANNEL_CLOSE		=> "channel close",
SSH_MSG_CHANNEL_REQUEST		=> "channel request",
SSH_MSG_CHANNEL_SUCCESS		=> "channel success",
SSH_MSG_CHANNEL_FAILURE		=> "channel failure",
};

init()
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	bufio->open("/dev/null", Bufio->OREAD);
	env = load Env Env->PATH;
	str = load String String->PATH;
	random = load Random Random->PATH;
	kr = load Keyring Keyring->PATH;
	base16 = load Encoding Encoding->BASE16PATH;
	base64 = load Encoding Encoding->BASE64PATH;
	fact = load Factotum Factotum->PATH;
	fact->init();
	util = load Util0 Util0->PATH;
	util->init();
	sshfmt = load Sshfmt Sshfmt->PATH;
	sshfmt->init();

	group1primestr := 
		"FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1"+
		"29024E088A67CC74020BBEA63B139B22514A08798E3404DD"+
		"EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245"+
		"E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"+
		"EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE65381"+
		"FFFFFFFFFFFFFFFF";
	group1prime := IPint.strtoip(group1primestr, 16);
	group1gen := IPint.inttoip(2);
	dhgroup1 = ref Dh (group1prime, group1gen, 1024);

	group14primestr :=
		"FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1"+
		"29024E088A67CC74020BBEA63B139B22514A08798E3404DD"+
		"EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245"+
		"E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"+
		"EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D"+
		"C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F"+
		"83655D23DCA3AD961C62F356208552BB9ED529077096966D"+
		"670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B"+
		"E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9"+
		"DE2BCBF6955817183995497CEA956AE515D2261898FA0510"+
		"15728E5A8AACAA68FFFFFFFFFFFFFFFF";
	group14prime := IPint.strtoip(group14primestr, 16);
	group14gen := IPint.inttoip(2);
	dhgroup14 = ref Dh (group14prime, group14gen, 2048);
}

msgname(t: int): string
{
	if(t < 0 || t >= len msgnames || msgnames[t] == nil)
		return "unknown";
	return msgnames[t];
}

Rssh.text(m: self ref Rssh): string
{
	return sprint("%q (%d)", msgname(m.t), m.t);
}

Sshc.kexbusy(c: self ref Sshc): int
{
	return c.state & (Kexinitsent|Kexinitreceived|Newkeyssent|Newkeysreceived|Havenewkeys);
}


handshake(fd: ref Sys->FD, addr: string, wantcfg: ref Cfg): (ref Sshc, string)
{
	b := bufio->fopen(fd, Bufio->OREAD);
	if(b == nil)
		return (nil, sprint("bufio fopen: %r"));

	lident := "SSH-2.0-inferno0";
	if(sys->fprint(fd, "%s\r\n", lident) < 0)
		return (nil, sprint("write: %r"));

	rident: string;
	for(;;) {
		rident = b.gets('\n');
		if(rident == nil || rident[len rident-1] != '\n')
			return (nil, sprint("eof before identification line"));
		if(!prefix("SSH-", rident))
			continue;
		if(len rident > 255)
			return (nil, sprint("identification from remote too long, invalid"));

		rident = rident[:len rident-1];
		if(suffix("\r", rident))
			rident = rident[:len rident-1];

		# note: rident (minus \n or \r\n) is used in key exchange, must be left as is
		(rversion, rname) := str->splitstrl(rident[len "SSH-":], "-");
		if(rname == nil)
			return (nil, sprint("bad remote identification %#q, missing 'name'", rident));
		rcomment: string;
		(rname, rcomment) = str->splitstrl(rname[1:], " ");
		say(sprint("have remote version %q, name %q, comment %q", rversion, rname, rcomment));

		if(rversion != "2.0" && rversion != "1.99")
			return (nil, sprint("unsupported remote version %#q", rversion));
		break;
	}

	nilkey := ref Keys (Cryptalg.new(Enone), Macalg.new(Enone));
	c := ref Sshc (
		fd, b, addr,
		big 0, big 0, big 0, big 0,
		nilkey, nilkey, nil, nil,
		lident, rident,
		wantcfg, nil,
		nil,
		1, 1, nil,
		0, nil, nil, nil
	);
	return (c, nil);
}

keyexchangestart(c: ref Sshc): string
{
	say(sprint("keyexchangestart"));
	nilnames := valnames(nil);
	cookie := random->randombuf(Random->NotQuiteRandom, 16);
	vals := array[] of {
		valbuf(cookie),
		valnames(c.wantcfg.kex),
		valnames(c.wantcfg.hostkey),
		valnames(c.wantcfg.encout), valnames(c.wantcfg.encin),
		valnames(c.wantcfg.macout), valnames(c.wantcfg.macin),
		valnames(c.wantcfg.comprout), valnames(c.wantcfg.comprin),
		nilnames, nilnames,
		valbool(0),
		valint(0),
	};

	kexinitpkt := packpacket(c, SSH_MSG_KEXINIT, vals, 0);
	say(sprint("-> %s", msgname(SSH_MSG_KEXINIT)));
	err := writebuf(c, kexinitpkt);
	if(err != nil)
		return err;
	say("wrote kexinit packet");
	c.state |= Kexinitsent;

	size := 1;
	for(i := 0; i < len vals; i++)
		size += vals[i].size();
	c.clkexinit = array[size] of byte;
	o := 0;
	c.clkexinit[o++] = byte SSH_MSG_KEXINIT;
	for(i = 0; i < len vals; i++)
		o += vals[i].packbuf(c.clkexinit[o:]);

	return nil;
}

keyexchange(c: ref Sshc, m: ref Rssh): (int, string)
{
	d := m.buf[1:];
	case m.t {
	SSH_MSG_KEXINIT =>
		kexmsg := list of {16, Tnames, Tnames, Tnames, Tnames, Tnames, Tnames, Tnames, Tnames, Tnames, Tnames, Tbool, Tint};
		(v, err) := eparsepacket(c, d, kexmsg);
		if(err != nil)
			return (0, err);
		c.srvkexinit = m.buf;
		o := 1;
		remcfg := ref Cfg (
			nil,
			v[o++].getnames(),
			v[o++].getnames(),
			v[o++].getnames(), v[o++].getnames(),
			v[o++].getnames(), v[o++].getnames(),
			v[o++].getnames(), v[o++].getnames(),
			nil
		);
		say("languages client to server: "+v[o++].text());
		say("languages server to client: "+v[o++].text());
		say("first kex packet follows: "+v[o++].text());
		say("out config:");
		say(c.wantcfg.text());
		say("from remote:");
		say(remcfg.text());
		(c.usecfg, err) = Cfg.match(c.wantcfg, remcfg);
		if(err != nil) {
			disconnect(c, SSH_DISCONNECT_PROTOCOL_ERROR, "protocol error");
			return (0, err);
		}
		say("chosen config:\n"+c.usecfg.text());

		c.auths = authmethods(c.usecfg.authmeth);
		(c.newtosrv, c.newfromsrv) = Keys.new(c.usecfg);
		case hd c.usecfg.kex {
		"diffie-hellman-group1-sha1" =>
			c.kex = ref Kex (0, dhgroup1, nil, nil);
		"diffie-hellman-group14-sha1" =>
			c.kex = ref Kex (0, dhgroup14, nil, nil);
		"diffie-hellman-group-exchange-sha1" =>
			c.kex = ref Kex (1, nil, nil, nil);
		* =>
			raise "unknown kex alg";
		}

		c.state |= Kexinitreceived;
		if((c.state & Kexinitsent) == 0) {
			err = keyexchangestart(c);
			if(err != nil)
				return (0, err);
		}

		msgt: int;
		msg: array of ref Val;
		if(c.kex.new) {
			msg = array[] of {valint(Dhexchangemin), valint(Dhexchangewant), valint(Dhexchangemax)};
			msgt = SSH_MSG_KEX_DH_GEX_REQUEST;
		} else {
			gendh(c.kex);
			msg = array[] of {valmpint(c.kex.e)};
			msgt = SSH_MSG_KEXDH_INIT;
		}
		err = writepacket(c, msgt, msg);
		if(err != nil)
			return (0, err);

	SSH_MSG_NEWKEYS =>
		(nil, err) := eparsepacket(c, d, nil);
		if(err != nil)
			return (0, err);
		say("server wants to use newkeys");

		if((c.state & Havenewkeys) == 0)
			return (0, sprint("server wants to use new keys, but none are pending"));

		if((c.state & Newkeyssent) == 0) {
			say("writing newkeys to remote");
			err = writepacket(c, SSH_MSG_NEWKEYS, nil);
			if(err != nil)
				return (0, "writing newkeys: "+err);
			c.state |= Newkeyssent;
		}

		say("now using new keys");
		c.tosrv = c.newtosrv;
		c.fromsrv = c.newfromsrv;
		c.newtosrv = c.newfromsrv = nil;
		c.nkeypkts = c.nkeybytes = big 0;
		c.state &= ~(Kexinitsent|Kexinitreceived|Newkeyssent|Newkeysreceived|Havenewkeys);
		return (1, nil);

	SSH_MSG_KEXDH_INIT =>
		return (0, sprint("received SSH_MSG_KEXDH_INIT from server, invalid"));

	SSH_MSG_KEXDH_REPLY or
	SSH_MSG_KEXDH_GEX_INIT to # xxx is gex init valid?
	SSH_MSG_KEXDH_GEX_REQUEST =>

		if((c.state & (Kexinitsent|Kexinitreceived)) != (Kexinitsent|Kexinitreceived))
			return (0, sprint("kexdh messages but no kexinit in progress!"));
		if((c.state & Havenewkeys) != 0)
			return (0, sprint("kexhd message, but already Havenewkeys?"));

		if(c.kex.new && m.t == SSH_MSG_KEX_DH_GEX_REPLY || !c.kex.new && m.t == SSH_MSG_KEXDH_REPLY) {
			kexdhreplmsg := list of {Tstr, Tmpint, Tstr};
			(v, err) := eparsepacket(c, d, kexdhreplmsg);
			if(err != nil)
				return (0, err);
			#string    server public host key and certificates (K_S)
			#mpint     f
			#string    signature of H

			srvksval := v[0];
			srvfval := v[1];
			srvks := srvksval.getbytes();
			srvf := srvfval.getipint();
			srvsigh := v[2].getbytes();

			# C then
			# computes K = f^x mod p, H = hash(V_C || V_S || I_C || I_S || K_S
			# || e || f || K), and verifies the signature s on H.
			say("calculating key from f from remote");
			key := srvf.expmod(c.kex.x, c.kex.dhgroup.prime);
			say("have key");
			c.kex.x = nil;
			#say(sprint("key %s", key.iptostr(16)));
			hashbufs: list of array of byte;
			if(c.kex.new)
				hashbufs = list of {
					valstr(c.lident).pack(),
					valstr(c.rident).pack(),
					valbytes(c.clkexinit).pack(),
					valbytes(c.srvkexinit).pack(),
					srvksval.pack(),
					valint(Dhexchangemin).pack(),
					valint(Dhexchangewant).pack(),
					valint(Dhexchangemax).pack(),
					valmpint(c.kex.dhgroup.prime).pack(),
					valmpint(c.kex.dhgroup.gen).pack(),
					valmpint(c.kex.e).pack(),
					srvfval.pack(),
					valmpint(key).pack()
				};
			else
				hashbufs = list of {
					valstr(c.lident).pack(),
					valstr(c.rident).pack(),
					valbytes(c.clkexinit).pack(),
					valbytes(c.srvkexinit).pack(),
					srvksval.pack(),
					valmpint(c.kex.e).pack(),
					srvfval.pack(),
					valmpint(key).pack()
				};
			dhhash := sha1many(hashbufs);
			zero(c.clkexinit);
			c.clkexinit = nil;
			zero(c.srvkexinit);
			c.srvkexinit = nil;
			srvfval = nil;

			say(sprint("hash on dh %s", fingerprint(dhhash)));
			if(c.sessionid == nil)
				c.sessionid = dhhash;

			err = verifyhostkey(c, hd c.usecfg.hostkey, srvks, srvsigh, dhhash);
			if(err != nil)
				return (0, err);

			# calculate session keys
			#Encryption keys MUST be computed as HASH, of a known value and K, as follows:
			#o  Initial IV client to server: HASH(K || H || "A" || session_id)
			#    (Here K is encoded as mpint and "A" as byte and session_id as raw
			#   data.  "A" means the single character A, ASCII 65).
			#o  Initial IV server to client: HASH(K || H || "B" || session_id)
			#o  Encryption key client to server: HASH(K || H || "C" || session_id)
			#o  Encryption key server to client: HASH(K || H || "D" || session_id)
			#o  Integrity key client to server: HASH(K || H || "E" || session_id)
			#o  Integrity key server to client: HASH(K || H || "F" || session_id)

			keypack := valmpint(key).pack();

			keybitsout := c.newtosrv.crypt.keybits;
			keybitsin := c.newfromsrv.crypt.keybits;
			macbitsout := c.newtosrv.mac.keybytes*8;
			macbitsin := c.newfromsrv.mac.keybytes*8;

			ivc2s := genkey(keybitsout, keypack, dhhash, "A", c.sessionid);
			ivs2c := genkey(keybitsin, keypack, dhhash, "B", c.sessionid);
			enckeyc2s := genkey(keybitsout, keypack, dhhash, "C", c.sessionid);
			enckeys2c := genkey(keybitsin, keypack, dhhash, "D", c.sessionid);
			mackeyc2s := genkey(macbitsout, keypack, dhhash, "E", c.sessionid);
			mackeys2c := genkey(macbitsin, keypack, dhhash, "F", c.sessionid);

			say("ivc2s "+hex(ivc2s));
			say("ivs2c "+hex(ivs2c));
			say("enckeyc2s "+hex(enckeyc2s));
			say("enckeys2c "+hex(enckeys2c));
			say("mackeyc2s "+hex(mackeyc2s));
			say("mackeys2c "+hex(mackeys2c));

			c.newtosrv.crypt.setup(enckeyc2s, ivc2s);
			c.newfromsrv.crypt.setup(enckeys2c, ivs2c);
			c.newtosrv.mac.setup(mackeyc2s);
			c.newfromsrv.mac.setup(mackeys2c);

			c.state |= Havenewkeys;
			say("we want to use newkeys");
			err = writepacket(c, SSH_MSG_NEWKEYS, nil);
			if(err != nil)
				return (0, "writing newkeys: "+err);
			c.state |= Newkeyssent;

		} else if(c.kex.new && m.t == SSH_MSG_KEX_DH_GEX_GROUP) {
			(v, err) := eparsepacket(c, d, list of {Tmpint, Tmpint});
			if(err != nil)
				return (0, err);
			prime := v[0].getipint();
			gen := v[1].getipint();
			# xxx should verify these values are sane.
			c.kex.dhgroup = ref Dh (prime, gen, prime.bits());

			gendh(c.kex);

			msg := array[] of {valmpint(c.kex.e)};
			err = writepacket(c, SSH_MSG_KEX_DH_GEX_INIT, msg);
			if(err != nil)
				return (0, err);
		} else {
			return (0, sprint("unexpected kex message, t %d, new %d", m.t, c.kex.new));
		}

	* =>
		return (0, sprint("unexpected message type %d", m.t));
	}
	return (0, nil);
}

userauth(c: ref Sshc, m: ref Rssh): (int, string)
{
	d := m.buf[1:];

	case m.t {
	SSH_MSG_USERAUTH_FAILURE =>
		# byte         SSH_MSG_USERAUTH_FAILURE
		# name-list    authentications that can continue
		# boolean      partial success
		(v, err) := eparsepacket(c, d, list of {Tnames, Tbool});
		if(err != nil)
			return (0, err);
		warn("auth failure");
		say(sprint("other auth methods that can be tried: %s", v[0].text()));
		say(sprint("partical succes %s", v[1].text()));

		return (0, userauthnext(c));

	SSH_MSG_USERAUTH_SUCCESS =>
		(nil, err) := eparsepacket(c, d, nil);
		if(err != nil)
			return (0, err);
		say("logged in!");
		return (1, nil);

	* =>
		return (0, sprint("unrecognized userauth message %d", m.t));
	}
}

userauthnext(c: ref Sshc): string
{
	for(; c.auths != nil; c.auths = tl c.auths) {
		meth := hd c.auths;

		fatal: int;
		err: string;
		case meth {
		"rsa" =>
			(fatal, err) = authpkrsa(c);
		"dsa" =>
			(fatal, err) = authpkdsa(c);
		"password" =>
			(fatal, err) = authpassword(c);
		* =>
			raise "unknown authentication method";
		}
		if(err != nil && fatal)
			return err;
		else if(err != nil)
			warn(err);
		else
			return nil;
	}
	return "all authentication methods failed";
}

gendh(k: ref Kex)
{
	# 1. C generates a random number x (1 < x < q) and computes
	# e = g^x mod p.  C sends e to S.
	say(sprint("gendh, nbits %d", k.dhgroup.nbits));
	k.x = IPint.random(k.dhgroup.nbits, k.dhgroup.nbits); # xxx sane params?
	say(sprint("k.x %s", k.x.iptostr(16)));
	k.e = k.dhgroup.gen.expmod(k.x, k.dhgroup.prime);
	say(sprint("k.e %s", k.e.iptostr(16)));
}


Cryptalg.new(t: int): ref Cryptalg
{
	case t {
	Enone =>	return ref Cryptalg.None (8, 0);
	Eaes128cbc =>	return ref Cryptalg.Aes (kr->AESbsize, 128, nil);
	Eaes192cbc =>	return ref Cryptalg.Aes (kr->AESbsize, 192, nil);
	Eaes256cbc =>	return ref Cryptalg.Aes (kr->AESbsize, 256, nil);
	Eblowfish =>	return ref Cryptalg.Blowfish (kr->BFbsize, 128, nil);  # broken!
	Eidea =>	return ref Cryptalg.Idea (kr->IDEAbsize, 128, nil);
	Earcfour =>	return ref Cryptalg.Arcfour (8, 128, nil);
	E3descbc =>	return ref Cryptalg.Tripledes (kr->DESbsize, 192, nil, nil);  # 168 bits are used
	Eaes128ctr =>	return ref Cryptalg.Aesctr (kr->AESbsize, 128, nil, nil);
	Eaes192ctr =>	return ref Cryptalg.Aesctr (kr->AESbsize, 192, nil, nil);
	Eaes256ctr =>	return ref Cryptalg.Aesctr (kr->AESbsize, 256, nil, nil);
	Earcfour128 =>	return ref Cryptalg.Arcfour2 (8, 128, nil);
	Earcfour256 =>	return ref Cryptalg.Arcfour2 (8, 256, nil);
	}
	raise "missing case";
}

xindex(a: array of string, s: string): int
{
	for(i := 0; i < len a; i++)
		if(a[i] == s)
			return i;
	raise "missing value";
}


Cryptalg.news(name: string): ref Cryptalg
{
	t := xindex(knownenc, name);
	return Cryptalg.new(t);
}

genkey(needbits: int, k, h: array of byte, x: string, sessionid: array of byte): array of byte
{
	nbytes := needbits/8;
	say(sprint("genkey, needbits %d, nbytes %d", needbits, nbytes));
	k1 := sha1many(list of {k, h, array of byte x, sessionid});
	if(nbytes <= len k1)
		return k1[:nbytes];
	ks := list of {k1};
	key := k1;
	while(len key < nbytes) {
		kx := sha1many(k::h::ks);
		nkey := array[len key+len kx] of byte;
		nkey[:] = key;
		nkey[len key:] = kx;
		key = nkey;
		ks = rev(kx::rev(ks));
	}
	return key[:nbytes];
}

Cryptalg.setup(cc: self ref Cryptalg, key, ivec: array of byte)
{
	pick c := cc {
	None =>	;
	Aes =>		c.state = kr->aessetup(key, ivec);
	Blowfish =>	c.state = kr->blowfishsetup(key, ivec); # broken!
	Idea =>		c.state = kr->ideasetup(key, ivec);
	Arcfour =>	c.state = kr->rc4setup(key);
	Tripledes =>
		c.states = array[] of {
			kr->dessetup(key[0:8], nil),
			kr->dessetup(key[8:16], nil),
			kr->dessetup(key[16:24], nil)
		};
		c.iv = ivec[:8];
	Aesctr =>
		c.counter = array[kr->AESbsize] of byte;
		c.counter[:] = ivec[:kr->AESbsize];
		c.key = array[len key] of byte;
		c.key[:] = key;
	Arcfour2 =>
		c.state = kr->rc4setup(key);
		c.crypt(array[1536] of byte, 1536, kr->Encrypt);
	}
}

Cryptalg.crypt(cc: self ref Cryptalg, buf: array of byte, n, direction: int)
{
	pick c := cc {
	None =>	;
	Aes =>		kr->aescbc(c.state, buf, n, direction);
	Blowfish =>	kr->blowfishcbc(c.state, buf, n, direction); # broken!
	Idea =>		kr->ideacbc(c.state, buf, n, direction);
	Arcfour or
	Arcfour2  =>	kr->rc4(c.state, buf, n);
	Tripledes =>
		buf = buf[:n];
		while(len buf > 0) {
			block := buf[:kr->DESbsize];
			if(direction == kr->Encrypt) {
				bufxor(block, c.iv);
				kr->desecb(c.states[0], block, len block, kr->Encrypt);
				kr->desecb(c.states[1], block, len block, kr->Decrypt);
				kr->desecb(c.states[2], block, len block, kr->Encrypt);
				c.iv[:] = block;
				buf = buf[len block:];
			} else {
				orig := array[len block] of byte;
				orig[:] = block;
				kr->desecb(c.states[2], block, len block, kr->Decrypt);
				kr->desecb(c.states[1], block, len block, kr->Encrypt);
				kr->desecb(c.states[0], block, len block, kr->Decrypt);
				bufxor(block, c.iv);
				c.iv[:] = orig;
				buf = buf[len block:];
			}
		}
	Aesctr =>
		key := array[kr->AESbsize] of byte;
		for(o := 0; o < n; o += kr->AESbsize) {
			key[:] = c.counter;

			# can we just keep a copy of the state after setup?  so we have to do it only once
			state := kr->aessetup(c.key, array[kr->AESbsize] of {* => byte 0});
			kr->aescbc(state, key, kr->AESbsize, kr->Encrypt);

			block := buf[o:min(n, o+kr->AESbsize)];
			bufxor(block, key);
			bufincr(c.counter);
		}
	}
}

bufxor(dst, key: array of byte)
{
	for(i := 0; i < len dst; i++)
		dst[i] ^= key[i];
}

bufincr(d: array of byte)
{
	for(i := len d-1; i >= 0; i--)
		if(++d[i] != byte 0)
			break;
}


Macalg.new(t: int): ref Macalg
{
	case t {
	Mnone =>	return ref Macalg.None (0, 0, nil);
	Msha1 =>	return ref Macalg.Sha1 (kr->SHA1dlen, kr->SHA1dlen, nil);
	Msha1_96 =>	return ref Macalg.Sha1_96 (96/8, kr->SHA1dlen, nil);
	Mmd5 =>		return ref Macalg.Md5 (kr->MD5dlen, kr->MD5dlen, nil);
	Mmd5_96 =>	return ref Macalg.Md5_96 (96/8, kr->MD5dlen, nil);
	* =>	raise "missing case";
	}
}

Macalg.news(name: string): ref Macalg
{
	t := xindex(knownmac, name);
	return Macalg.new(t);
}

Macalg.setup(mm: self ref Macalg, key: array of byte)
{
	mm.key = key[:mm.keybytes];
}

Macalg.hash(mm: self ref Macalg, bufs: list of array of byte, hash: array of byte)
{
	pick m := mm {
	None =>
		return;
	Sha1 or
	Sha1_96 =>
		state: ref DigestState;
		digest := array[kr->SHA1dlen] of byte;
		for(; bufs != nil; bufs = tl bufs)
			state = kr->hmac_sha1(hd bufs, len hd bufs, m.key, nil, state);
		kr->hmac_sha1(nil, 0, m.key, digest, state);
		hash[:] = digest[:m.nbytes];
	Md5 or
	Md5_96 =>
		state: ref DigestState;
		digest := array[kr->MD5dlen] of byte;
		for(; bufs != nil; bufs = tl bufs)
			state = kr->hmac_md5(hd bufs, len hd bufs, m.key, nil, state);
		kr->hmac_md5(nil, 0, m.key, digest, state);
		hash[:] = digest[:m.nbytes];
	* =>
		raise "missing case";
	}
}



sha1der := array[] of {
byte 16r30, byte 16r21,
byte 16r30, byte 16r09,
byte 16r06, byte 16r05,
byte 16r2b, byte 16r0e, byte 16r03, byte 16r02, byte 16r1a,
byte 16r05, byte 16r00,
byte 16r04, byte 16r14,
};
rsasha1msg(d: array of byte, msglen: int): array of byte
{
	h := sha1(d);
	msg := array[msglen] of {* => byte 16rff};
	msg[0] = byte 0;
	msg[1] = byte 1;
	msg[len msg-(1+len sha1der+len h)] = byte 0;
	msg[len msg-(len sha1der+len h):] = sha1der;
	msg[len msg-len h:] = h;
	return msg;
}

authpkrsa(c: ref Sshc): (int, string)
{
	say("doing rsa public-key authentication");

	fd := sys->open("/mnt/factotum/rpc", Sys->ORDWR);
	if(fd == nil)
		return (0, sprint("open factotum: %r"));
	(v, a) := fact->rpc(fd, "start", sys->aprint("proto=rsa role=client addr=%q %s", c.addr, c.wantcfg.keyspec));
	if(v == "ok")
		(v, a) = fact->rpc(fd, "read", nil);  # xxx should probably try all keys available.  needs some code.
	if(v != "ok")
		return (0, sprint("factotum: %s: %s", v, string a));
	(rsaepubs, rsans) := str->splitstrl(string a, " ");
	if(rsans == nil)
		return (0, "bad response for rsa keys from factotum");
	rsans = rsans[1:];
	rsaepub := IPint.strtoip(rsaepubs, 16);
	rsan := IPint.strtoip(rsans, 16);
	say(sprint("from factotum, rsaepub %s, rsan %s", rsaepub.iptostr(16), rsan.iptostr(16)));

	# our public key
	pkvals := array[] of {
		valstr("ssh-rsa"),
		valmpint(rsaepub),
		valmpint(rsan),
	};
	pkblob := packvals(pkvals, 0);

	# data to sign
	sigdatvals := array[] of {
		valbytes(c.sessionid),
		valbyte(byte SSH_MSG_USERAUTH_REQUEST),
		valstr("sshtest"),
		valstr("ssh-connection"),
		valstr("publickey"),
		valbool(1),
		valstr("ssh-rsa"),
		valbytes(pkblob),
	};
	sigdatblob := packvals(sigdatvals, 0);

	# sign it
	say("rsa hash: "+fingerprint(sha1(sigdatblob)));
	sigmsg := rsasha1msg(sigdatblob, rsan.bits()/8);
	sigm := IPint.bebytestoip(sigmsg);
	say(sprint("mp to sign: %s", sigm.iptostr(16)));

	(v, a) = fact->rpc(fd, "write", array of byte base16->enc(sigmsg));
	say(sprint("wrote messasge to sign to factotum, resp %q", v));
	if(v == "ok")
		(v, a) = fact->rpc(fd, "read", nil);
	if(v != "ok")
		return (0, sprint("factotum: %s: %s", v, string a));
	say(sprint("response: %s", string a));
	sigbuf := base16->dec(string a);

	sigvals := array[] of {valstr("ssh-rsa"), valbytes(sigbuf)};
	sig := packvals(sigvals, 0);

	authvals := array[] of {
		valstr("sshtest"),
		valstr("ssh-connection"),
		valstr("publickey"),
		valbool(1),
		valstr("ssh-rsa"),
		valbytes(pkblob),
		valbytes(sig),
	};
	return (1, writepacket(c, SSH_MSG_USERAUTH_REQUEST, authvals));
}

authpkdsa(c: ref Sshc): (int, string)
{
	say("doing dsa public-key authentication");

	fd := sys->open("/mnt/factotum/rpc", Sys->ORDWR);
	if(fd == nil)
		return (0, sprint("open factotum: %r"));
	(v, a) := fact->rpc(fd, "start", sys->aprint("proto=dsa role=client addr=%q %s", c.addr, c.wantcfg.keyspec));
	if(v == "ok")
		(v, a) = fact->rpc(fd, "read", nil);  # xxx should probably try all keys available.  needs some code.
	if(v != "ok")
		return (0, sprint("factotum: %s: %s", v, string a));
	pkl := sys->tokenize(string a, " ").t1;
	if(len pkl != 4)
		return (0, "bad response for public dsa key from factotum");
	pk := l2a(pkl);
	p := IPint.strtoip(pk[0], 16);
	q := IPint.strtoip(pk[1], 16);
	alpha := IPint.strtoip(pk[2], 16);
	key := IPint.strtoip(pk[3], 16);

	# our public key
	pkvals := array[] of {
		valstr("ssh-dss"),
		valmpint(p),
		valmpint(q),
		valmpint(alpha),
		valmpint(key),
	};
	pkblob := packvals(pkvals, 0);

	# data to sign
	sigdatvals := array[] of {
		valbytes(c.sessionid),
		valbyte(byte SSH_MSG_USERAUTH_REQUEST),
		valstr("sshtest"),
		valstr("ssh-connection"),
		valstr("publickey"),
		valbool(1),
		valstr("ssh-dss"),
		valbytes(pkblob),
	};
	sigdatblob := packvals(sigdatvals, 0);

	# sign it
	(v, a) = fact->rpc(fd, "write", array of byte base16->enc(sha1(sigdatblob)));
	if(v == "ok")
		(v, a) = fact->rpc(fd, "read", nil);
	if(v != "ok")
		return (0, sprint("factotum: %s: %s", v, string a));
	sigtoks := sys->tokenize(string a, " ").t1;
	sigbuf := array[20+20] of {* => byte 0};
	rbuf := base16->dec(hd sigtoks);
	sbuf := base16->dec(hd tl sigtoks);
	sigbuf[20-len rbuf:] = rbuf;
	sigbuf[40-len sbuf:] = sbuf;
	#hexdump(sigbuf);

	# the signature to put in the auth request packet
	sigvals := array[] of {valstr("ssh-dss"), valbytes(sigbuf)};
	sig := packvals(sigvals, 0);

	authvals := array[] of {
		valstr("sshtest"),
		valstr("ssh-connection"),
		valstr("publickey"),
		valbool(1),
		valstr("ssh-dss"),
		valbytes(pkblob),
		valbytes(sig),
	};
	return (1, writepacket(c, SSH_MSG_USERAUTH_REQUEST, authvals));
}

authpassword(c: ref Sshc): (int, string)
{
	say("doing password authentication");
	(user, pass) := fact->getuserpasswd(sprint("proto=pass role=client service=ssh addr=%q %s", c.addr, c.wantcfg.keyspec));
	if(user == nil)
		return (0, sprint("no username"));
	vals := array[] of {
		valstr(user),
		valstr("ssh-connection"),
		valstr("password"),
		valbool(0),
		valstr(pass),
	};
	return (1, writepacketpad(c, SSH_MSG_USERAUTH_REQUEST, vals, 100));
}


verifyhostkey(c: ref Sshc, name: string, ks, sig, h: array of byte): string
{
	case name {
	"ssh-rsa" =>	return verifyrsa(c, ks, sig, h);
	"ssh-dss" =>	return verifydsa(c, ks, sig, h);
	}
	raise "missing case";
}

verifyhostkeyfile(c: ref Sshc, alg, fp, hostkey: string): string
{
	# file contains lines with quoted strings:
	# addr [alg1 fp1 hostkey1] [alg2 fp2 hostkey2]

	# note: for now, the code below assumes only one alg is used per address.
	# if a different alg is attempted to verify than what we have on file, deny it too.
	# this should help when an attacker attempts a man-in-the-middle and simply
	# doesn't offer the type of host key all clients have been using.

	# ideally, this should be handled by factotum (or something similar).
	# the addresses themselves are somewhat sensitive (openssh hashes them so they can't be used as attack vectors).
	# so keeping them hidden from others is good.  also, this does /dev/cons mangling from a library...

	p := sprint("%s/lib/sshkeys", env->getenv("home"));
	b := bufio->open(p, sys->OREAD);
	if(b == nil)
		return sprint("open %q: %r", p);
	lineno := 0;
	for(;;) {
		l := b.gets('\n');
		if(l == nil)
			break;
		lineno++;
		t := l2a(str->unquoted(l));
		if(len t == 0 || (len t-1) % 3 != 0)
			return sprint("%s:%d: malformed host key", p, lineno);
		if(t[0] != c.addr)
			continue;
		for(o := 1; o+3 <= len t; o += 3) {
			if(t[o] != alg)
				continue;
			if(t[o+1] == fp && t[o+2] == hostkey)
				return nil;  # match
			return sprint("%s:%d: mismatching %#q host key for %q, remote claims %s, key file says %s", p, lineno, alg, c.addr, fp, t[o+1]);
		}
		return sprint("%s:%d: have host key for address, but not for algorithm %#q", p, lineno, alg);
	}

	# address unknown, have to ask user to add it.
	cfd := sys->open("/dev/cons", Sys->ORDWR);
	if(cfd == nil)
		return sprint("open /dev/cons: %r");
	if(sys->fprint(cfd, "%s: address %#q not present, add %#q host key %s? [yes/no]\n", p, c.addr, alg, fp) < 0)
		return sprint("write /dev/cons: %r");
	for(;;) {
		n := sys->read(cfd, buf := array[128] of byte, len buf);
		if(n <= 0)
			return "key denied by user";
		s := string buf[:n];
		if(s == "yes\n" || s == "y\n") {
			fd := sys->open(p, Sys->OWRITE);
			if(fd == nil)
				return sprint("open %s for writing: %r", p);
			sys->seek(fd, big 0, Sys->SEEKEND);
			sys->fprint(fd, "%q %q %q %q\n", c.addr, alg, fp, hostkey);
			return nil;
		} else if(s == "\n") {
			continue;
		} else
			return "key denied by user";
	}
	
}

verifyrsa(c: ref Sshc, ks, sig, h: array of byte): string
{
	# ssh-rsa host key:
	#string    "ssh-rsa"
	#mpint     e
	#mpint     n

	(keya, err) := eparsepacket(c, ks, list of {Tstr, Tmpint, Tmpint});
	if(err != nil)
		return "bad ssh-rsa host key: "+err;
	signame := keya[0].getstr();
	if(signame != "ssh-rsa")
		return sprint("host key not ssh-rsa, but %q", signame);
	srvrsae := keya[1];
	srvrsan := keya[2];
	say(sprint("server rsa key, e %s, n %s", srvrsae.text(), srvrsan.text()));
	rsan := srvrsan.getipint();
	rsae := srvrsae.getipint();

	fp := fingerprint(md5(ks));
	hostkey := base64->enc(ks);
	say("rsa fingerprint: "+fp);
	err = verifyhostkeyfile(c, "ssh-rsa", fp, hostkey);
	if(err != nil)
		return err;

	# signature
	# string    "ssh-rsa"
	# string    rsa_signature_blob
	siga := keya;
	(siga, err) = eparsepacket(c, sig, list of {Tstr, Tstr});
	if(err != nil)
		return "bad ssh-rsa signature: "+err;
	signame = siga[0].getstr();
	if(signame != "ssh-rsa")
		return sprint("signature not ssh-rsa, but %q", signame);
	sigblob := siga[1].getbytes();
	#say("sigblob:");
	#hexdump(sigblob);

	rsapk := ref RSApk (rsan, rsae);
	sigmsg := rsasha1msg(h, rsan.bits()/8);
	rsasig := ref RSAsig (IPint.bebytestoip(sigblob));
	ok := rsapk.verify(rsasig, IPint.bebytestoip(sigmsg));
	if(!ok)
		return "rsa signature does not match";
	return nil;
}

verifydsa(c: ref Sshc, ks, sig, h: array of byte): string
{
	# string    "ssh-dss"
	# mpint     p
	# mpint     q
	# mpint     g
	# mpint     y

	(keya, err) := eparsepacket(c, ks, list of {Tstr, Tmpint, Tmpint, Tmpint, Tmpint});
	if(err != nil)
		return "bad ssh-dss host key: "+err;
	if(keya[0].getstr() != "ssh-dss")
		return sprint("host key not ssh-dss, but %q", keya[0].getstr());
	srvdsap := keya[1];
	srvdsaq := keya[2];
	srvdsag := keya[3];
	srvdsay := keya[4];
	say(sprint("server dsa key, p %s, q %s, g %s, y %s", srvdsap.text(), srvdsaq.text(), srvdsag.text(), srvdsay.text()));

	fp := fingerprint(md5(ks));
	hostkey := base64->enc(ks);
	say("dsa fingerprint: "+fp);
	err = verifyhostkeyfile(c, "ssh-dss", fp, hostkey);
	if(err != nil)
		return err;

	# string    "ssh-dss"
	# string    dss_signature_blob

	#   The value for 'dss_signature_blob' is encoded as a string containing
	#   r, followed by s (which are 160-bit integers, without lengths or
	#   padding, unsigned, and in network byte order).
	siga := keya;
	(siga, err) = eparsepacket(c, sig, list of {Tstr, Tstr});
	if(err != nil)
		return "bad ssh-dss signature: "+err;
	signame := siga[0].getstr();
	if(signame != "ssh-dss")
		return sprint("signature not ssh-dss, but %q", signame);
	sigblob := siga[1].getbytes();
	if(len sigblob != 2*160/8) {
		say(sprint("sigblob, length %d", len sigblob));
		hexdump(sigblob);
		return "bad signature blob for ssh-dss";
	}
	srvdsar := IPint.bytestoip(sigblob[:20]);
	srvdsas := IPint.bytestoip(sigblob[20:]);
	say(sprint("signature on dsa, r %s, s %s", srvdsar.iptostr(16), srvdsas.iptostr(16)));

	dsapk := ref DSApk (srvdsap.getipint(), srvdsaq.getipint(), srvdsag.getipint(), srvdsay.getipint());
	dsasig := ref DSAsig (srvdsar, srvdsas);
	dsamsg := IPint.bytestoip(sha1(h));
	say(sprint("dsamsg, %s", dsamsg.iptostr(16)));
	ok := dsapk.verify(dsasig, dsamsg);
	if(!ok)
		return "dsa hash signature does not match";
	say("dsa hash signature matches");
	return nil;
}


packvals(v: array of ref Val, withlength: int): array of byte
{
	lensize := 0;
	if(withlength)
		lensize = 4;

	size := 0;
	for(i := 0; i < len v; i++)
		size += v[i].size();

	buf := array[lensize+size] of byte;
	if(withlength)
		p32i(buf, 0, size);

	o := lensize;
	for(i = 0; i < len v; i++)
		o += v[i].packbuf(buf[o:]);
	if(o != len buf)
		raise "packerror";
	return buf;
}

packpacket(c: ref Sshc, t: int, v: array of ref Val, minpktlen: int): array of byte
{
	say(sprint("packpacket, t %d", t));

	k := c.tosrv;
	pktunit := max(Packetunitmin, k.crypt.bsize);
	minpktlen = max(Pktlenmin, minpktlen);

	size := 4+1;  # pktlen, padlen
	size += 1;  # type
	for(i := 0; i < len v; i++)
		size += v[i].size();

	padlen := pktunit - size % pktunit;
	if(padlen < Padmin)
		padlen += pktunit;
	if(size+padlen < minpktlen)
		padlen += pktunit + pktunit * ((minpktlen-(size+padlen))/pktunit);
	size += padlen;
	say(sprint("packpacket, total buf %d, pktlen %d, padlen %d, maclen %d", size, size-4, padlen, k.mac.nbytes));

	d := array[size+k.mac.nbytes] of byte;

	o := 0;
	o = p32i(d, o, len d-k.mac.nbytes-4);  # length
	d[o++] = byte padlen;  # pad length
	d[o++] = byte t;  # type
	for(i = 0; i < len v; i++)
		o += v[i].packbuf(d[o:]);
	d[o:] = random->randombuf(Random->NotQuiteRandom, padlen);  # xxx reallyrandom is way too slow for me on inferno on openbsd
	o += padlen;
	if(o != len d-k.mac.nbytes)
		raise "internal error packing message";

	if(k.mac.nbytes > 0) {
		seqbuf := array[4] of byte;
		p32(seqbuf, 0, c.outseq);
		k.mac.hash(seqbuf::d[:len d-k.mac.nbytes]::nil, d[len d-k.mac.nbytes:]);
	}
	c.outseq++;
	if(c.outseq >= Seqmax)
		c.outseq = big 0;
	c.nkeypkts++;
	c.nkeybytes += big (len d-k.mac.nbytes);
	k.crypt.crypt(d, len d-k.mac.nbytes, kr->Encrypt);
	return d;
}

writepacketpad(c: ref Sshc, t: int, a: array of ref Val, minpktlen: int): string
{
	d := packpacket(c, t, a, minpktlen);
say(sprint("-> %s", msgname(t)));
	return writebuf(c, d);
}

writepacket(c: ref Sshc, t: int, a: array of ref Val): string
{
	d := packpacket(c, t, a, 0);
say(sprint("-> %s", msgname(t)));
	return writebuf(c, d);
}

writebuf(c: ref Sshc, d: array of byte): string
{
	n := sys->write(c.fd, d, len d);
	if(n != len d)
		return sprint("write: %r");
	return nil;
}

disconnect(c: ref Sshc, code: int, errmsg: string): string
{
	msg := array[] of {
		valint(code),
		valstr(errmsg),
		valstr(""),
	};
	return writepacket(c, SSH_MSG_DISCONNECT, msg);
}

ioerror(s: string)
{
	raise "io:"+s;
}

protoerror(s: string)
{
	raise "proto:"+s;
}

readpacket(c: ref Sshc): (ref Rssh, string, string)
{
	{
		return (xreadpacket(c), nil, nil);
	} exception x {
	"io:*" =>
		return (nil, x[len "io:":], nil);
	"proto:*" =>
		return (nil, nil, x[len "proto:":]);
	}
}

xreadpacket(c: ref Sshc): ref Rssh
{
	say("readpacket");

	k := c.fromsrv;
	pktunit := max(Packetunitmin, k.crypt.bsize);

	lead := array[pktunit] of byte;
	n := c.b.read(lead, len lead);
	if(n < 0)
		ioerror(sprint("read packet length: %r"));
	if(n != len lead)
		ioerror("short read for packet length");

	k.crypt.crypt(lead, len lead, kr->Decrypt);

	pktlen := g32i(lead, 0).t0;
	padlen := int lead[4];
	paylen := pktlen-1-padlen;
	say(sprint("readpacket, pktlen %d, padlen %d, paylen %d, maclen %d", pktlen, padlen, paylen, k.mac.nbytes));

	if(4+pktlen+k.mac.nbytes > Pktlenmax)
		protoerror(sprint("packet too large: 4+pktlen %d+maclen %d > pktlenmax %d", pktlen, k.mac.nbytes, Pktlenmax));
	if((4+pktlen) % pktunit != 0)
		protoerror(sprint("bad padding, 4+pktlen %d %% pktunit %d = %d (!= 0)", pktlen, pktunit, (4+pktlen) % pktunit));
	if(4+pktlen < Pktlenmin)
		protoerror(sprint("packet too small: 4+pktlen %d < Packetmin %d", pktlen, Pktlenmin));

	if(paylen > Payloadmax)
		protoerror(sprint("payload too large: paylen %d > Payloadmax %d", paylen, Payloadmax));
	if(paylen <= 0)
		protoerror(sprint("payload too small: paylen %d <= 0", paylen));
	if(padlen < Padmin)
		protoerror(sprint("padding too small: padlen %d < Padmin %d", padlen, Padmin));

	total := array[4+pktlen+k.mac.nbytes] of byte;
	total[:] = lead;
	rem := total[len lead:];

	n = c.b.read(rem, len rem);
	if(n < 0)
		ioerror(sprint("read payload: %r"));
	if(n != len rem)
		ioerror("short read for payload");

	k.crypt.crypt(rem, len rem-k.mac.nbytes, kr->Decrypt);

	if(k.mac.nbytes> 0) {
		# mac = MAC(key, sequence_number || unencrypted_packet)
		seqbuf := array[4] of byte;
		p32(seqbuf, 0, c.inseq);

		pktdigest := total[len total-k.mac.nbytes:];
		calcdigest := array[k.mac.nbytes] of byte;
		k.mac.hash(seqbuf::total[:len total-k.mac.nbytes]::nil, calcdigest);
		if(!eq(calcdigest, pktdigest))
			protoerror(sprint("bad packet signature, have %s, expected %s", hex(pktdigest), hex(calcdigest)));
	}

	m := ref Rssh (c.inseq, 0, total[4+1:len total-padlen-k.mac.nbytes]);
	m.t = int m.buf[0];
	
	c.inseq++;
	if(c.inseq >= Seqmax)
		c.inseq = big 0;
	c.nkeypkts++;
	c.nkeybytes += big (len lead+len rem-k.mac.nbytes);

	return m;
}

eparsepacket(c: ref Sshc, buf: array of byte, l: list of int): (array of ref Val, string)
{
	(vals, err) := parsepacket(buf, l);
	if(err != nil)
		disconnect(c, SSH_DISCONNECT_PROTOCOL_ERROR, "protocol error");
	return (vals, err);
}

parsepacket(buf: array of byte, l: list of int): (array of ref Val, string)
{
	(v, o, err) := parse(buf, l);
	if(err != nil)
		return (nil, err);
	if(o != len buf)
		return (nil, sprint("leftover bytes, %d of %d used", o, len buf));
	return (v, nil);
}

parse(buf: array of byte, l: list of int): (array of ref Val, int, string)
{
	{
		(v, o) := xparse(buf, l);
		return (v, o, nil);
	} exception x {
	"parse:*" =>
		return (nil, 0, x[len "parse:":]);
	}
}

parseerror(s: string)
{
	raise "parse:"+s;
}

xparse(buf: array of byte, l: list of int): (array of ref Val, int)
{
	r: list of ref Val;
	o := 0;
	i := 0;
	for(; l != nil; l = tl l) {
		#say(sprint("parse, %d elems left, %d bytes left", len l, len buf-o));
		t := hd l;
		case t {
		Tbyte =>
			if(o+1 > len buf)
				parseerror("short buffer for byte");
			r = ref Val.Byte (buf[o++])::r;
		Tbool =>
			if(o+1 > len buf)
				parseerror("short buffer for byte");
			r = ref Val.Bool (int buf[o++])::r;
		Tint =>
			if(o+4 > len buf)
				parseerror("short buffer for int");
			e := ref Val.Int;
			(e.v, o) = g32i(buf, o);
			r = e::r;
		Tbig =>
			if(o+8 > len buf)
				parseerror("short buffer for big");
			e := ref Val.Big;
			(e.v, o) = g64(buf, o);
			r = e::r;
		Tnames or
		Tstr or
		Tmpint =>
			if(o+4 > len buf)
				parseerror("short buffer for int for length");
			length: int;
			(length, o) = g32i(buf, o);
			if(o+length > len buf)
				parseerror("short buffer for name-list/string/mpint");
			case t {
			Tnames =>
				# xxx disallow non-printable?
				# xxx better verify tokens
				r = ref Val.Names (sys->tokenize(string buf[o:o+length], ",").t1)::r;
			Tstr =>
				r = ref Val.Str (buf[o:o+length])::r;
			Tmpint =>
				#say(sprint("read mpint of length %d", length));
				if(length == 0) {
					r = valmpint(IPint.strtoip("0", 10))::r;
				} else {
					neg := 0;
					if(int buf[o] & 16r80) {
						raise "negative incoming";
						neg = 1;
						buf[o] &= byte 16r7f;
					}
					v := IPint.bebytestoip(buf[o:o+length]);
					if(neg) {
						buf[o] |= byte 16r80;
						v = v.neg();
					}
					r = valmpint(v)::r;
					#say(sprint("new mpint %s", (hd r).text()));
				}
			}
			o += length;
		* =>
			if(t < 0)
				parseerror(sprint("unknown type %d requested", t));
			if(o+t > len buf)
				parseerror("short buffer for byte-array");
			r = ref Val.Str (buf[o:o+t])::r;
			o += t;
		}
		#say(sprint("new val, size %d, text %s", (hd r).size(), (hd r).text()));
		i++;
	}
	return (l2a(rev(r)), o);
}

hexdump(buf: array of byte)
{
	s := "";
	i := 0;
	while(i < len buf) {
		for(j := 0; j < 16 && i < len buf; j++) {
			if((i & 1) == 0)
				s += " ";
			s += sprint("%02x", int buf[i]);
			i++;
		}
		s += "\n";
	}
	say(s);
}

sha1many(l: list of array of byte): array of byte
{
	st: ref Keyring->DigestState;
	for(; l != nil; l = tl l)
		st = kr->sha1(hd l, len hd l, nil, st);
	kr->sha1(nil, 0, h := array[Keyring->SHA1dlen] of byte, st);
	return h;
}

md5(d: array of byte): array of byte
{
	h := array[Keyring->MD5dlen] of byte;
	kr->md5(d, len d, h, nil);
	return h;
}

sha1(d: array of byte): array of byte
{
	h := array[Keyring->SHA1dlen] of byte;
	kr->sha1(d, len d, h, nil);
	return h;
}

fingerprint(d: array of byte): string
{
	s := "";
	for(i := 0; i < len d; i++)
		s += sprint(":%02x", int d[i]);
	if(s != nil)
		s = s[1:];
	return s;
}

hex(d: array of byte): string
{
	s := "";
	for(i := 0; i < len d; i++)
		s += sprint(" %02x", int d[i]);
	if(s != nil)
		s = s[1:];
	return s;
}


Val.getbyte(v: self ref Val): byte
{
	pick vv := v {
	Byte =>	return byte vv.v;
	}
	raise "not byte";
}

Val.getbool(v: self ref Val): int
{
	pick vv := v {
	Bool =>	return vv.v;
	}
	raise "not bool";
}

Val.getint(v: self ref Val): int
{
	pick vv := v {
	Int =>	return vv.v;
	}
	raise "not int";
}

Val.getbig(v: self ref Val): big
{
	pick vv := v {
	Big =>	return vv.v;
	}
	raise "not big";
}

Val.getnames(v: self ref Val): list of string
{
	pick vv := v {
	Names =>	return vv.l;
	}
	raise "not names";
}

Val.getipint(v: self ref Val): ref IPint
{
	pick vv := v {
	Mpint =>	return vv.v;
	}
	raise "not mpint";
}

Val.getstr(v: self ref Val): string
{
	pick vv := v {
	Str =>	return string vv.buf;
	}
	raise "not string";
}

Val.getbytes(v: self ref Val): array of byte
{
	pick vv := v {
	Str =>	return vv.buf;
	}
	raise "not string (bytes)";
}


Val.pack(v: self ref Val): array of byte
{
	n := v.size();
	d := array[n] of byte;
	v.packbuf(d);
	return d;
}

Val.text(vv: self ref Val): string
{
	pick v := vv {
	Byte =>	return string v.v;
	Bool =>
		if(v.v)
			return "true";
		return "false";
	Int =>	return string v.v;
	Big =>	return string v.v;
	Names =>	return join(v.l, ",");
	Str =>	return "string "+string v.buf;
	Mpint =>
		return "ipint "+v.v.iptostr(16);
	Buf =>	return "buf "+string v.buf;
	}
}

Val.size(vv: self ref Val): int
{
	pick v := vv {
	Byte =>	return 1;
	Bool =>	return 1;
	Int =>	return 4;
	Big =>	return 8;
	Names =>	return 4+len join(v.l, ",");
	Str =>	return 4+len v.buf;
	Mpint =>	return len packmpint(v.v);
	Buf =>	return len v.buf;
	}
}

packmpint(v: ref IPint): array of byte
{
	zero := IPint.strtoip("0", 10);
	cmp := zero.cmp(v);
	if(cmp == 0) {
		d := array[4] of byte;
		p32i(d, 0, 0);
		return d;
	}
	if(v.cmp(zero) < 0)
		raise "negative";
	buf := v.iptobebytes();
	if(int buf[0] & 16r80) {
		nbuf := array[len buf+1] of byte;
		nbuf[0] = byte 0;
		nbuf[1:] = buf;
		buf = nbuf;
	}
	d := array[4+len buf] of byte;
	p32i(d, 0, len buf);
	d[4:] = buf;
	#say(sprint("Val.Mpint.pack, hex %s", hex(d)));
	return d;
}

Val.packbuf(vv: self ref Val, d: array of byte): int
{
	pick v := vv {
	Byte =>
		d[0] = v.v;
		return 1;
	Bool =>
		d[0] = byte v.v;
		return 1;
	Int =>
		return p32i(d, 0, v.v);
	Big =>
		return p64(d, 0, v.v);
	Names =>
		s := array of byte join(v.l, ",");
		p32i(d, 0, len s);
		d[4:] = s;
		return 4+len s;
	Str =>
		p32i(d, 0, len v.buf);
		d[4:] = v.buf;
		return 4+len v.buf;
	Mpint =>
		buf := packmpint(v.v);
		d[:] = buf;
		return len buf;
	Buf =>
		d[:] = v.buf;
		return len v.buf;
	};
}


Keys.new(cfg: ref Cfg): (ref Keys, ref Keys)
{
	a := ref Keys (Cryptalg.news(hd cfg.encout), Macalg.news(hd cfg.macout));
	b := ref Keys (Cryptalg.news(hd cfg.encin), Macalg.news(hd cfg.macin));
	return (a, b);
}

algnames(aa: array of string, ta: array of int): list of string
{
	l: list of string;
	for(i := len ta-1; i >= 0; i--)
		l = aa[ta[i]]::l;
	return l;
}

Cfg.default(): ref Cfg
{
	kex := algnames(knownkex, defkex);
	hostkey := algnames(knownhostkey, defhostkey);
	enc := algnames(knownenc, defenc);
	mac := algnames(knownmac, defmac);
	compr := algnames(knowncompr, defcompr);
	authmeth := algnames(knownauthmeth, defauthmeth);
	return ref Cfg ("", kex, hostkey, enc, enc, mac, mac, compr, compr, authmeth);
}

Cfg.set(c: self ref Cfg, t: int, l: list of string): string
{
	knowns := array[] of {
		knownkex,
		knownhostkey,
		knownenc,
		knownmac,
		knowncompr,
		knownauthmeth,
	};
	known := knowns[t];
	if(l == nil)
		return "list empty";

next:
	for(n := l; n != nil; n = tl n) {
		for(i := 0; i < len known; i++)
			if(known[i] == hd n)
				continue next;
		return "unsupported: "+hd n;
	}
	case t {
	Akex =>		c.kex = l;
	Ahostkey =>	c.hostkey = l;
	Aenc =>		c.encin = c.encout = l;
	Amac =>		c.macin = c.macout = l;
	Acompr =>	c.comprin = c.comprout = l;
	Aauthmeth =>	c.authmeth = l;
	}
	return nil;
}

Cfg.setopt(c: self ref Cfg, ch: int, s: string): string
{
	t: int;
	case ch {
	'K' =>	t = Akex;
	'H' =>	t = Ahostkey;
	'e' =>	t = Aenc;
	'm' =>	t = Amac;
	'C' =>	t = Acompr;
	'A' =>	t = Aauthmeth;
	'k' =>	c.keyspec = s;
		return nil;
	* =>	return "unrecognized ssh config option";
	}
	(l, err) := parsenames(s);
	if(err == nil)
		err = c.set(t, l);
	return err;
}

Nomatch: exception(string);
firstmatch(name: string, a, b: list of string): list of string raises Nomatch
{
	for(; a != nil; a = tl a)
		for(l := b; l != nil; l = tl l)
			if(hd a == hd l)
				return hd a::nil;
	raise Nomatch(sprint("no match for %q", name));
}

Cfg.match(client, server: ref Cfg): (ref Cfg, string)
{
	n := ref Cfg;
	{
		n.kex = firstmatch("kex exchange", client.kex, server.kex);
		n.hostkey = firstmatch("server host key", client.hostkey, server.hostkey);
		n.encout = firstmatch("encryption to server", client.encout, server.encout);
		n.encin = firstmatch("encryption from server", client.encin, server.encin);
		n.macout = firstmatch("mac to server", client.macout, server.macout);
		n.macin = firstmatch("mac from server", client.macin, server.macin);
		n.comprout = firstmatch("compression to server", client.comprout, server.comprout);
		n.comprin = firstmatch("compression from server", client.comprin, server.comprin);
	}exception e{
	Nomatch =>
		return (nil, e);
	}
	n.keyspec = client.keyspec;
	n.authmeth = client.authmeth;
	return (n, nil);
}


Cfg.text(c: self ref Cfg): string
{
	s := "config:";
	s += "\n\tkey exchange: "+join(c.kex, ",");
	s += "\n\tserver host key: "+join(c.hostkey, ",");
	s += "\n\tencryption to server: "+join(c.encout, ",");
	s += "\n\tencryption from server: "+join(c.encin, ",");
	s += "\n\tmac to server: "+join(c.macout, ",");
	s += "\n\tmac from server: "+join(c.macin, ",");
	s += "\n\tcompression to server: "+join(c.comprout, ",");
	s += "\n\tcompression from server: "+join(c.comprin, ",");
	s += "\n";
	return s;
}

parsenames(s: string): (list of string, string)
{
	l: list of string;
	e: string;
	while(s != nil) {
		(e, s) = str->splitstrl(s, ",");
		if(e == nil)
			return (nil, "malformed list");
		l = e::l;
		if(s != nil)
			s = s[1:];
	}
	return (l, nil);
}

authmethods(l: list of string): list of string
{
	r: list of string;
	for(; l != nil; l = tl l)
		case hd l{
		"publickey" =>
			r = "dsa"::"rsa"::r;
		"password" =>
			r = "password"::r;
		}
	return rev(r);
}

zero(d: array of byte)
{
	d[:] = array[len d] of {* => byte 0};
}

say(s: string)
{
	if(dflag)
		warn(s);
}

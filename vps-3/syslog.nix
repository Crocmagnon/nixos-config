{ config, ... } : {
  services.syslog-ng = {
    enable = true;
    extraConfig = ''
@version: 4.3
@include "scl.conf"

options { chain_hostnames(off); flush_lines(0); use_dns(no); use_fqdn(no);
	  dns_cache(no); owner("root"); group("adm"); perm(0640);
	  stats(freq(0)); bad_hostname("^gconfd$");
};

source s_src {
       system();
       internal();
};

rewrite ovh-token {
    set("{{ ldp_ovh_token }}", value(".SDATA.token@29084.X-OVH-TOKEN"));
};

destination ovhPaaSLogs {
    network("gra3.logs.ovh.com"
        port(6514)
        transport("tls")
        flags(syslog-protocol)
        ts_format("iso")
        frac-digits(6)
        tls(peer-verify("required-trusted") ca_dir("/etc/ssl/certs/"))
        keep-alive(yes)
        so_keepalive(yes)
    );
};

@include "${config.age.secrets."ovh-ldp-token".path}"

log { source(s_src); rewrite(ovh-token); destination(ovhPaaSLogs); };
'';
  };
}

{ config, ...} : {
  services.filebeat = {
    enable = true;
    inputs = {
      journald.id = "everything";
    };
    settings = {
      fields_under_root = true;
      fields.X-OVH-TOKEN = { _secret = config.age.secrets.ovh-ldp-token.path; };
      output.elasticsearch = {
        enabled = false;
      };
      output.logstash = {
        enabled = true;
        hosts = ["gra3.logs.ovh.com:5044"];
        compression_level = 3;
        ssl.enabled = true;
      };
    };
  };
}

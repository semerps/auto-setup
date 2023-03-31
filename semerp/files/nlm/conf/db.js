module.exports = {
  name: "NLM SERVER",
  version: "1.5",
  env: process.env.NODE_ENV || "production",
  port: process.env.PORT || "5040",
  base_url: process.env.BASE_URL || "http://serverIP",
  db: {
    uri:
      process.env.MONGODB_URI ||
      "mongodb://mongodb_username:mongodb_password@mongodb.namespace.svc.cluster.local:27017/sem",
    authDb: process.env.authDB || "admin",
  },
  ssl: false,
  /*
  ssl: {
    key: "analytics_uzmar.key",
    certificate: "analytics.uzmar.com.crt",
    passphrase: "ksdfj8732as!."
  } */
  sem: {
    server: "http://semerp-latest.namespace.svc.cluster.local:8090/sem",
    username: "Administrator",
    password: "1",
  },
  amqp: {
    uri: "amqp://uzmartech:Sem123654%40@rabbitmq.semerp.svc.cluster.local:5672/semerp",
  },
  elasticSearch: {
    node: "https://elasticsearch.namespace.svc.cluster.local:9200",
    auth: {
      apiKey: "elk_api_key",
    },
  },

  autoTopicLogger: [
    {
      queueName: "nlm-sem-request-log",
      routeKey: "log.monitor.*",
      exchange: "sem-scheduler",
      elasticIndex: "sem-request",
    },
    {
      queueName: "nlm-sem-exceptions-log",
      routeKey: "general.exception",
      exchange: "sem-scheduler",
      elasticIndex: "sem-exceptions",
    },
  ],
};

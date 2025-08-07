module.exports = {
  name: "NLM SERVER",
  version: "1.9",
  env: process.env.NODE_ENV || "production",
  port: process.env.PORT || "30040",
  base_url: process.env.BASE_URL || "http://serverIP",
  db: {
    uri:
      process.env.MONGODB_URI ||
      "mongodb://mongodb_username:mongodb_password@mongodb.namespace.svc.cluster.local:27017/sem",
    authDb: process.env.authDB || "admin",
  },
  ssl: false,
  sem: {
    server: "http://semerp-COMPANY_TAG.namespace.svc.cluster.local:8090/sem",
    username: "Administrator",
    password: "pass",
  },
  amqp: {
    uri: "amqp://uzmartech:Sem123654@@rabbitmq.semerp.svc.cluster.local:5672/semerp",
  },
  elasticSearch: {
    node: "http://elasticsearch.namespace.svc.cluster.local:9200",
    // auth: { apiKey: "your-api-key" }, // If needed
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
    // {
    //   queueName: "nlm-sem-asfat-eys-approvement-dlx",
    //   routeKey: "asfat.eys.approvement.dlx.*",
    //   exchange: "sem-dlx",
    //   elasticIndex: "asfat-eys-approvement-dlx",
    // },
    // {
    //   queueName: "nlm-sem-asfat-eys-approvement",
    //   routeKey: "asfat.eys.approvement.*",
    //   exchange: "sem-scheduler",
    //   elasticIndex: "asfat-eys-approvement",
    // },
    // {
    //   queueName: "nlm-sem-orkestra-personnel-dlx",
    //   routeKey: "orkestra.personnel.dlx.*",
    //   exchange: "sem-dlx",
    //   elasticIndex: "orkestra-personnel-dlx",
    // },
    // {
    //   queueName: "nlm-sem-orkestra-personnel",
    //   routeKey: "orkestra.personnel.*",
    //   exchange: "sem-integration",
    //   elasticIndex: "orkestra-personnel",
    // },
  ],
};

job "studycenter" {
  datacenters = ["scs"]

  group "studycenter-frontend" {
    count = 3

    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "studycenter-frontend"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.studycenter-frontend.rule=Host(`discretemath.ca`)",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "5s"
      }
    }

    task "studycenter-frontend" {
      driver = "docker"

      config {
        image = "ghcr.io/carletoncomputersciencestudycenter/studycenter-client/studycenter-client:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }

  group "studycenter-backend" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        to = 3000
      }
    }

    service {
      name = "studycenter-backend"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.studycenter-backend.rule=Host(`api.discretemath.ca`)",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "5s"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "studycenter-postgres"
              local_bind_port  = 5432
            }
            upstreams {
              destination_name = "studycenter-redis"
              local_bind_port  = 6379
            }
          }
        }
      }
    }

    task "studycenter-backend" {
      driver = "docker"

      config {
        image = "ghcr.io/carletoncomputersciencestudycenter/studycenter-api/studycenter-api:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      env {
        STUDYCENTER_API_DATABASE_HOST = "${NOMAD_UPSTREAM_ADDR_studycenter_postgres}"
        STUDYCENTER_API_REDIS_HOST    = "redis://${NOMAD_UPSTREAM_ADDR_studycenter_redis}:6379"
      }
    }
  }

  group "studycenter-database" {
    count = 1

    network {
      mode = "bridge"

      port "postgres" {
        to = 5432
      }

      port "redis" {
        to = 6379
      }
    }

    service {
      connect {
        sidecar_service {}
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image = "postgres:12"
        ports = ["postgres"]
      }

      env {
        POSTGRES_USER     = "postgres"
        POSTGRES_PASSWORD = "1234"
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      service {
        name = "studycenter-postgres"
        port = "postgres"
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:6"
        ports = ["redis"]
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      service {
        name = "studycenter-redis"
        port = "redis"
      }
    }
  }
}
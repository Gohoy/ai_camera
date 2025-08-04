#!/bin/bash

# AI相机云端服务部署脚本
# 使用方法: ./deploy.sh [start|stop|restart|logs|status]

set -e

# 配置
PROJECT_NAME="ai-camera"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
    
    # 检查curl
    if ! command -v curl &> /dev/null; then
        log_error "curl未安装，请先安装curl"
        exit 1
    fi
    
    log_info "依赖检查完成"
}

# 创建必要目录
create_directories() {
    log_info "创建必要目录..."
    
    mkdir -p models
    mkdir -p logs
    mkdir -p ssl
    mkdir -p grafana/dashboards
    mkdir -p grafana/datasources
    
    log_info "目录创建完成"
}

# 生成配置文件
generate_configs() {
    log_info "生成配置文件..."
    
    # 生成.env文件
    if [ ! -f "$ENV_FILE" ]; then
        cat > "$ENV_FILE" << EOF
# AI相机云端服务环境配置
PYTHONPATH=/app
MODEL_CACHE_DIR=/app/models
LOG_LEVEL=INFO

# Redis配置
REDIS_HOST=redis
REDIS_PORT=6379

# 安全配置
SECRET_KEY=your-secret-key-here
API_KEY=your-api-key-here

# 监控配置
PROMETHEUS_ENABLED=true
GRAFANA_ENABLED=true
EOF
        log_info "已生成.env文件"
    fi
    
    # 生成nginx配置
    if [ ! -f "nginx.conf" ]; then
        cat > "nginx.conf" << EOF
events {
    worker_connections 1024;
}

http {
    upstream ai_camera_backend {
        server ai-camera-server:8000;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            proxy_pass http://ai_camera_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        location /health {
            proxy_pass http://ai_camera_backend/api/health;
        }
    }
}
EOF
        log_info "已生成nginx.conf文件"
    fi
    
    # 生成Prometheus配置
    if [ ! -f "prometheus.yml" ]; then
        cat > "prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ai-camera-server'
    static_configs:
      - targets: ['ai-camera-server:8000']
    metrics_path: '/metrics'
    
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
    metrics_path: '/nginx_status'
EOF
        log_info "已生成prometheus.yml文件"
    fi
    
    log_info "配置文件生成完成"
}

# 启动服务
start_services() {
    log_info "启动AI相机云端服务..."
    
    # 构建镜像
    log_info "构建Docker镜像..."
    docker-compose -f "$COMPOSE_FILE" build
    
    # 启动服务
    log_info "启动服务..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    check_services
    
    log_info "服务启动完成"
}

# 停止服务
stop_services() {
    log_info "停止AI相机云端服务..."
    docker-compose -f "$COMPOSE_FILE" down
    log_info "服务已停止"
}

# 重启服务
restart_services() {
    log_info "重启AI相机云端服务..."
    docker-compose -f "$COMPOSE_FILE" restart
    log_info "服务已重启"
}

# 查看日志
show_logs() {
    log_info "显示服务日志..."
    docker-compose -f "$COMPOSE_FILE" logs -f
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    # 检查主服务
    if curl -f http://localhost:8000/api/health > /dev/null 2>&1; then
        log_info "✅ AI相机服务运行正常"
    else
        log_error "❌ AI相机服务异常"
    fi
    
    # 检查Redis
    if docker exec ai-camera-redis redis-cli ping > /dev/null 2>&1; then
        log_info "✅ Redis服务运行正常"
    else
        log_error "❌ Redis服务异常"
    fi
    
    # 检查Nginx
    if curl -f http://localhost:80 > /dev/null 2>&1; then
        log_info "✅ Nginx服务运行正常"
    else
        log_error "❌ Nginx服务异常"
    fi
    
    # 检查Prometheus
    if curl -f http://localhost:9090 > /dev/null 2>&1; then
        log_info "✅ Prometheus服务运行正常"
    else
        log_error "❌ Prometheus服务异常"
    fi
    
    # 检查Grafana
    if curl -f http://localhost:3000 > /dev/null 2>&1; then
        log_info "✅ Grafana服务运行正常"
    else
        log_error "❌ Grafana服务异常"
    fi
}

# 显示服务信息
show_info() {
    log_info "AI相机云端服务信息:"
    echo "  - 主服务: http://localhost:8000"
    echo "  - API文档: http://localhost:8000/docs"
    echo "  - 健康检查: http://localhost:8000/api/health"
    echo "  - Nginx代理: http://localhost:80"
    echo "  - Prometheus监控: http://localhost:9090"
    echo "  - Grafana可视化: http://localhost:3000 (admin/admin)"
    echo ""
    log_info "使用以下命令查看日志:"
    echo "  ./deploy.sh logs"
    echo ""
    log_info "使用以下命令停止服务:"
    echo "  ./deploy.sh stop"
}

# 清理服务
cleanup() {
    log_warn "清理所有服务和数据..."
    docker-compose -f "$COMPOSE_FILE" down -v
    docker system prune -f
    log_info "清理完成"
}

# 主函数
main() {
    case "${1:-start}" in
        start)
            check_dependencies
            create_directories
            generate_configs
            start_services
            show_info
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        logs)
            show_logs
            ;;
        status)
            check_services
            ;;
        cleanup)
            cleanup
            ;;
        *)
            echo "使用方法: $0 {start|stop|restart|logs|status|cleanup}"
            echo ""
            echo "命令说明:"
            echo "  start    - 启动所有服务"
            echo "  stop     - 停止所有服务"
            echo "  restart  - 重启所有服务"
            echo "  logs     - 查看服务日志"
            echo "  status   - 检查服务状态"
            echo "  cleanup  - 清理所有数据"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 
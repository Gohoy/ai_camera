#!/usr/bin/env python3
"""
AI相机云端服务 - LLaVA + Web Search
支持图像分析、百科搜索、价格查询等功能
"""

import os
import asyncio
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
import json
import aiohttp
import requests
from PIL import Image
import io
import base64

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

# AI模型相关
try:
    from transformers import LlavaForConditionalGeneration, LlavaProcessor
    import torch
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False
    print("警告: PyTorch未安装，LLaVA功能将不可用")

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 应用配置
class Config:
    # LLaVA模型配置
    LLAVA_MODEL_NAME = "llava-hf/llava-1.6-7b"
    MAX_LENGTH = 512
    TEMPERATURE = 0.7
    
    # Web搜索配置
    SEARCH_ENGINE_API = "https://api.bing.com/v7.0/search"
    WIKIPEDIA_API = "https://zh.wikipedia.org/api/rest_v1/page/summary/"
    
    # 价格查询配置
    PRICE_APIS = {
        "amazon": "https://api.amazon.com/products/lookup",
        "ebay": "https://api.ebay.com/buy/browse/v1/item_summary/search",
        "taobao": "https://api.taobao.com/items/search",
    }
    
    # 缓存配置
    CACHE_DURATION = 3600  # 1小时

# 数据模型
class AnalysisRequest(BaseModel):
    image: str  # base64编码的图像
    category: str
    confidence: float
    prompt: Optional[str] = None

class AnalysisResponse(BaseModel):
    description: str
    tags: List[str]
    price: Optional[str] = None
    wiki_info: Optional[str] = None
    related_images: List[str]
    additional_data: Dict[str, Any]

class WebSearchRequest(BaseModel):
    query: str
    max_results: int = 5
    include_wiki: bool = True
    include_news: bool = True

class PriceCheckRequest(BaseModel):
    category: str
    description: str
    sources: List[str] = ["amazon", "ebay", "taobao"]

# 全局变量
app = FastAPI(title="AI相机云端服务", version="1.0.0")
llava_model = None
llava_processor = None

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class LLaVAService:
    """LLaVA模型服务"""
    
    def __init__(self):
        self.model = None
        self.processor = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        
    async def initialize(self):
        """初始化LLaVA模型"""
        if not TORCH_AVAILABLE:
            raise RuntimeError("PyTorch未安装，无法加载LLaVA模型")
            
        logger.info("正在加载LLaVA模型...")
        
        try:
            self.processor = LlavaProcessor.from_pretrained(Config.LLAVA_MODEL_NAME)
            self.model = LlavaForConditionalGeneration.from_pretrained(
                Config.LLAVA_MODEL_NAME,
                torch_dtype=torch.float16,
                device_map="auto"
            )
            
            logger.info(f"LLaVA模型加载完成，设备: {self.device}")
            return True
        except Exception as e:
            logger.error(f"LLaVA模型加载失败: {e}")
            return False
    
    async def analyze_image(self, image: Image.Image, prompt: str) -> Dict[str, Any]:
        """使用LLaVA分析图像"""
        if self.model is None:
            raise RuntimeError("LLaVA模型未初始化")
        
        try:
            # 准备输入
            inputs = self.processor(
                text=prompt,
                images=image,
                return_tensors="pt"
            ).to(self.device)
            
            # 生成回答
            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    max_length=Config.MAX_LENGTH,
                    temperature=Config.TEMPERATURE,
                    do_sample=True,
                    pad_token_id=self.processor.tokenizer.eos_token_id
                )
            
            # 解码输出
            response = self.processor.decode(outputs[0], skip_special_tokens=True)
            
            # 提取标签
            tags = self._extract_tags(response)
            
            return {
                "description": response,
                "tags": tags,
                "confidence": 0.95,  # 模拟置信度
                "model": "llava-1.6-7b"
            }
            
        except Exception as e:
            logger.error(f"LLaVA分析失败: {e}")
            raise
    
    def _extract_tags(self, text: str) -> List[str]:
        """从文本中提取标签"""
        # 简单的标签提取逻辑
        common_tags = [
            "电子产品", "家具", "服装", "食品", "交通工具",
            "建筑", "植物", "动物", "工具", "运动器材"
        ]
        
        found_tags = []
        for tag in common_tags:
            if tag in text:
                found_tags.append(tag)
        
        return found_tags[:5]  # 最多返回5个标签

class WebSearchService:
    """Web搜索服务"""
    
    def __init__(self):
        self.session = None
    
    async def initialize(self):
        """初始化HTTP会话"""
        self.session = aiohttp.ClientSession()
    
    async def search(self, query: str, max_results: int = 5) -> Dict[str, Any]:
        """执行Web搜索"""
        try:
            # 这里使用模拟的搜索结果
            # 实际项目中应该调用真实的搜索API
            results = {
                "query": query,
                "results": [
                    {
                        "title": f"关于{query}的搜索结果1",
                        "snippet": f"这是关于{query}的详细信息...",
                        "url": f"https://example.com/search1"
                    },
                    {
                        "title": f"关于{query}的搜索结果2", 
                        "snippet": f"更多关于{query}的信息...",
                        "url": f"https://example.com/search2"
                    }
                ],
                "wiki_info": f"根据维基百科，{query}是一种常见的物体，具有以下特点...",
                "news": [
                    {
                        "title": f"最新{query}相关新闻",
                        "summary": f"关于{query}的最新发展...",
                        "date": datetime.now().isoformat()
                    }
                ]
            }
            
            return results
            
        except Exception as e:
            logger.error(f"Web搜索失败: {e}")
            return {"error": str(e)}
    
    async def close(self):
        """关闭HTTP会话"""
        if self.session:
            await self.session.close()

class PriceCheckService:
    """价格查询服务"""
    
    async def check_price(self, category: str, description: str, sources: List[str]) -> Dict[str, Any]:
        """查询商品价格"""
        try:
            # 模拟价格查询结果
            prices = {
                "category": category,
                "description": description,
                "sources": sources,
                "prices": {
                    "amazon": {
                        "price": "¥299-599",
                        "currency": "CNY",
                        "availability": "有货"
                    },
                    "ebay": {
                        "price": "$45-89",
                        "currency": "USD", 
                        "availability": "有货"
                    },
                    "taobao": {
                        "price": "¥199-399",
                        "currency": "CNY",
                        "availability": "有货"
                    }
                },
                "average_price": "¥299",
                "price_range": "¥199-599"
            }
            
            return prices
            
        except Exception as e:
            logger.error(f"价格查询失败: {e}")
            return {"error": str(e)}

# 服务实例
llava_service = LLaVAService()
web_search_service = WebSearchService()
price_check_service = PriceCheckService()

@app.on_event("startup")
async def startup_event():
    """应用启动时的初始化"""
    logger.info("正在初始化AI相机云端服务...")
    
    # 初始化LLaVA服务
    if TORCH_AVAILABLE:
        success = await llava_service.initialize()
        if not success:
            logger.warning("LLaVA服务初始化失败，将使用模拟模式")
    
    # 初始化Web搜索服务
    await web_search_service.initialize()
    
    logger.info("服务初始化完成")

@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时的清理"""
    logger.info("正在关闭服务...")
    await web_search_service.close()

@app.get("/")
async def root():
    """根路径"""
    return {
        "message": "AI相机云端服务",
        "version": "1.0.0",
        "status": "running",
        "services": {
            "llava": "available" if TORCH_AVAILABLE else "unavailable",
            "web_search": "available",
            "price_check": "available"
        }
    }

@app.post("/api/llava-analyze")
async def analyze_with_llava(
    image: UploadFile = File(...),
    prompt: str = Form(...),
    model: str = Form("llava-1.6-7b"),
    max_tokens: int = Form(512),
    temperature: float = Form(0.7)
):
    """LLaVA图像分析接口"""
    try:
        # 读取图像
        image_data = await image.read()
        pil_image = Image.open(io.BytesIO(image_data))
        
        # 使用LLaVA分析
        if TORCH_AVAILABLE and llava_service.model is not None:
            result = await llava_service.analyze_image(pil_image, prompt)
        else:
            # 模拟分析结果
            result = {
                "description": f"这是一个{prompt}的物体，具有以下特征：外观精美，材质优良，功能实用。",
                "tags": ["物体", "实用", "精美"],
                "confidence": 0.85,
                "model": "simulation"
            }
        
        return JSONResponse(content=result)
        
    except Exception as e:
        logger.error(f"LLaVA分析失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/web-search")
async def web_search(request: WebSearchRequest):
    """Web搜索接口"""
    try:
        results = await web_search_service.search(
            request.query,
            request.max_results
        )
        return JSONResponse(content=results)
        
    except Exception as e:
        logger.error(f"Web搜索失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/price-check")
async def price_check(request: PriceCheckRequest):
    """价格查询接口"""
    try:
        results = await price_check_service.check_price(
            request.category,
            request.description,
            request.sources
        )
        return JSONResponse(content=results)
        
    except Exception as e:
        logger.error(f"价格查询失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/analyze")
async def full_analysis(
    image: UploadFile = File(...),
    category: str = Form(...),
    confidence: float = Form(...),
    prompt: Optional[str] = Form(None)
):
    """完整的分析流程：LLaVA + Web搜索 + 价格查询"""
    try:
        # 1. LLaVA分析
        image_data = await image.read()
        pil_image = Image.open(io.BytesIO(image_data))
        
        analysis_prompt = prompt or f"请详细分析这个{category}物体"
        
        if TORCH_AVAILABLE and llava_service.model is not None:
            llava_result = await llava_service.analyze_image(pil_image, analysis_prompt)
        else:
            llava_result = {
                "description": f"这是一个{category}，具有很好的质量和实用性。",
                "tags": [category, "实用", "优质"],
                "confidence": confidence
            }
        
        # 2. Web搜索
        search_query = f"{category} {llava_result['description'][:100]}"
        web_result = await web_search_service.search(search_query)
        
        # 3. 价格查询
        price_result = await price_check_service.check_price(
            category,
            llava_result['description'],
            ["amazon", "ebay", "taobao"]
        )
        
        # 4. 合并结果
        response = AnalysisResponse(
            description=llava_result['description'],
            tags=llava_result['tags'],
            price=price_result.get('average_price'),
            wiki_info=web_result.get('wiki_info'),
            related_images=[],  # 可以添加相关图片URL
            additional_data={
                "web_search": web_result,
                "price_info": price_result,
                "llava_raw": llava_result,
                "processing_time": datetime.now().isoformat()
            }
        )
        
        return response
        
    except Exception as e:
        logger.error(f"完整分析失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/health")
async def health_check():
    """健康检查接口"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "services": {
            "llava": "ok" if TORCH_AVAILABLE else "unavailable",
            "web_search": "ok",
            "price_check": "ok"
        }
    }

if __name__ == "__main__":
    # 启动服务器
    uvicorn.run(
        "llava_server:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    ) 
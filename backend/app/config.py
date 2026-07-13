from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # MongoDB Settings
    MONGO_URL: str
    DB_NAME: str = "live_db"

    DEEPGRAM_API_KEY: str
    GROQ_API_KEY: str
    ELEVENLABS_API_KEY: str = ""
    ELEVENLABS_VOICE_ID: str = "pNInz6obpgDQGcFmaJgB"

    GROQ_MODEL: str = "openai/gpt-oss-20b"
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"

    GOOGLE_API_KEY: str
    EMBEDDING_MODEL: str = "models/gemini-embedding-001"
    EMBEDDING_DIMENSIONS: int = 768
    CHUNK_SIZE: int = 1000
    CHUNK_OVERLAP: int = 250
    VECTOR_INDEX_NAME: str = "vector_index"
    DOCUMENT_CHUNKS_COLLECTION: str = "document_chunks"
    TENANT_ID: str = "mvp_tenant"

    #Hard Coded
    USER_ID: str = "mvp_user"

    # Force wss:// for the WebSocket URL even when the app sees http at the
    # origin (e.g. behind CloudFront -> ALB where TLS terminates at CloudFront).
    FORCE_SECURE_WEBSOCKET: bool = False
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
from lima.models.embedding.base import Embedding, EmbeddingModel

__all__ = [
    "Embedding",
    "EmbeddingModel",
]

# Optional: CLIP support
try:
    from lima.models.embedding.clip import CLIPModel

    __all__.append("CLIPModel")
except ImportError:
    pass

# Optional: MobileCLIP support
try:
    from lima.models.embedding.mobileclip import MobileCLIPModel

    __all__.append("MobileCLIPModel")
except ImportError:
    pass

# Optional: TorchReID support
try:
    from lima.models.embedding.treid import TorchReIDModel

    __all__.append("TorchReIDModel")
except ImportError:
    pass

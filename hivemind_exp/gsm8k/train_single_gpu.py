import logging
import torch
import gc

# GPU Optimization functions
def setup_gpu_optimization():
    """Configure GPU optimizations for GTX 1060"""
    if not torch.cuda.is_available():
        logging.warning("CUDA not available. Running on CPU.")
        return torch.device('cpu')
    
    logging.info(f"GPU Device: {torch.cuda.get_device_name()}")
    logging.info(f"CUDA Version: {torch.version.cuda}")
    
    # Memory optimizations
    torch.cuda.empty_cache()
    gc.collect()
    
    # CUDA optimizations
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    
    return torch.device('cuda')

# Needs to be before trl!
from hivemind_exp.runner.grpo_runner import GRPOArguments, GRPORunner

import colorlog
from trl import GRPOConfig, ModelConfig, TrlParser

from hivemind_exp.chain_utils import (
    ModalSwarmCoordinator,
    WalletSwarmCoordinator,
    setup_web3,
)
from hivemind_exp.gsm8k.generate_prompts import get_stage1_samples as gsm8k_stage1_samples
from hivemind_exp.dapo.generate_prompts import get_stage1_samples as dapo_stage1_samples
from hivemind_exp.runner.gensyn.testnet_grpo_runner import (
    TestnetGRPOArguments,
    TestnetGRPORunner,
)


def main():
    # Setup logging.
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    handler = colorlog.StreamHandler()
    handler.setFormatter(
        colorlog.ColoredFormatter("%(green)s%(levelname)s:%(name)s:%(message)s")
    )
    root_logger.addHandler(handler)

    # Setup GPU optimization
    device = setup_gpu_optimization()
    logging.info(f"Using device: {device}")
    
    # Log initial GPU memory state
    if torch.cuda.is_available():
        logging.info(f"Initial GPU memory allocated: {torch.cuda.memory_allocated() / 1024**2:.2f} MB")
        logging.info(f"Initial GPU memory cached: {torch.cuda.memory_reserved() / 1024**2:.2f} MB")

    parser = TrlParser((ModelConfig, GRPOArguments, TestnetGRPOArguments, GRPOConfig))  # type: ignore
    model_args, grpo_args, testnet_args, training_args = parser.parse_args_and_config()

    # Add GPU optimization settings to training args
    training_args.fp16 = True  # Enable mixed precision training
    training_args.gradient_accumulation_steps = 2  # Reduce memory usage
    
    # Run main training loop.
    contract_address = testnet_args.contract_address
    if org_id := testnet_args.modal_org_id:
        assert contract_address, "Contract address must be set!"
        runner = TestnetGRPORunner(
            ModalSwarmCoordinator(setup_web3(), contract_address, org_id)
        )
    elif priv_key := testnet_args.wallet_private_key:
        assert contract_address, "Contract address must be set!"
        runner = TestnetGRPORunner(
            WalletSwarmCoordinator(setup_web3(), contract_address, priv_key)
        )
    else:
        runner = GRPORunner()

    game = grpo_args.game
    match game:
        case "gsm8k":
            runner.run(model_args, grpo_args, training_args, gsm8k_stage1_samples)
        case "dapo":
            runner.run(model_args, grpo_args, training_args, dapo_stage1_samples)
        case _:
            raise ValueError()


if __name__ == "__main__":
    main()

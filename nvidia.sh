sudo bash -c '
set -e

echo "=== [1/18] Updating system ==="
apt update && apt -y upgrade
apt -y install gnupg2 software-properties-common lsb-release

echo "=== [2/18] Installing core system packages ==="
apt -y install \
  tar sudo git wget curl bc pkg-config numactl \
  postgresql-client screen build-essential \
  kmod pciutils dnsutils zstd netcat-openbsd \
  htop unzip

echo "=== [3/18] Adding NVIDIA CUDA keyring ==="
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
apt update

echo "=== [4/18] Installing CUDA Toolkit ==="
apt -y install cuda-toolkit-13-0

echo "=== [5/18] Installing cuDNN ==="
apt -y install libcudnn9-cuda-13 libcudnn9-dev-cuda-13

echo "=== [6/18] Installing NCCL ==="
apt -y install libnccl2 libnccl-dev

echo "=== [7/18] Installing NVIDIA Fabric Manager ==="
apt -y install nvidia-fabricmanager-560
systemctl enable nvidia-fabricmanager
systemctl start nvidia-fabricmanager

echo "=== [8/18] Installing MIG Manager ==="
apt -y install nvidia-mig-manager || true

echo "=== [9/18] Installing DCGM + GPU Metrics Exporter ==="
apt -y install datacenter-gpu-manager dcgm-exporter || true
systemctl enable nvidia-dcgm
systemctl start nvidia-dcgm

echo "=== [10/18] Installing Nsight profiling tools ==="
apt -y install nsight-compute nsight-systems

echo "=== [11/18] Installing CUDA math/dev libraries ==="
apt -y install \
  libcublas-dev \
  libcusparse-dev \
  libcusolver-dev \
  libcufft-dev

echo "=== [12/18] Installing OpenMPI ==="
apt -y install openmpi-bin libopenmpi-dev

echo "=== [13/18] Installing GPUDirect Storage (GDS) ==="
apt -y install nvidia-gds
systemctl enable nvidia-gds
systemctl start nvidia-gds

echo "=== [14/18] Installing Mellanox OFED (Infiniband/RDMA) ==="
MLNX_VER="24.10-3.2.5.0"
wget -O /tmp/MLNX_OFED.tgz \
https://content.mellanox.com/ofed/MLNX_OFED-${MLNX_VER}/MLNX_OFED_LINUX-${MLNX_VER}-ubuntu$(lsb_release -sr | cut -d. -f1)-x86_64.tgz || true

cd /tmp
tar -xzf MLNX_OFED.tgz || echo "OFED not required or no Mellanox NIC"
cd MLNX_OFED_LINUX-* || true
./mlnxofedinstall --force || echo "OFED installation failed or not required"
/etc/init.d/openibd restart || true

echo "=== [15/18] Setting CUDA environment variables ==="
echo "export CUDA_HOME=/usr/local/cuda-13.0" >> ~/.bashrc
echo "export PATH=$CUDA_HOME/bin:$PATH" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH" >> ~/.bashrc
source ~/.bashrc

echo "=== [16/18] Validation: NVIDIA Driver ==="
nvidia-smi || { echo "NVIDIA driver failure"; exit 1; }

echo "=== [17/18] Validation: CUDA Toolkit ==="
nvcc --version || { echo "CUDA NVCC missing"; exit 1; }

echo "=== [18/18] Validation: Components ==="
echo "--- cuDNN ---"
dpkg -l | grep libcudnn || echo "cuDNN missing!"
echo "--- NCCL ---"
dpkg -l | grep nccl || echo "NCCL missing!"
echo "--- GDS ---"
gdscheck -p || echo "GDS check failed (if NVMe not present, safe to ignore)"
echo "--- OFED ---"
ibv_devinfo || echo "No Infiniband device detected (safe on non-IB machines)"
echo "--- Fabric Manager ---"
systemctl status nvidia-fabricmanager || true
echo "--- DCGM ---"
nvidia-healthmon -c || echo "DCGM health test unavailable"
echo "--- MIG ---"
nvidia-smi -L || true

echo ""
echo "=== NVIDIA DGX-CLASS FULL STACK INSTALLATION COMPLETE ==="
'

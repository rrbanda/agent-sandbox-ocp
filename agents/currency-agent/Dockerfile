FROM python:3.11-slim

WORKDIR /app

# Install uv for fast package management
RUN pip install uv

# Copy project files
COPY pyproject.toml .
COPY *.py ./currency_agent/

# Install dependencies
RUN uv pip install --system .

# Expose A2A port
EXPOSE 10000

# Run the agent
CMD ["python", "-m", "currency_agent"]

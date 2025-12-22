"""
Portainer API Client for Code Execution Sandbox

Pre-configured client for Portainer API access.
Available to Claude-generated code as: import portainer_client as pc
"""

import os
import requests
from typing import Dict, List, Optional, Any


class PortainerClient:
    """Simple Portainer API client with authentication."""

    def __init__(self):
        self.base_url = os.getenv('PORTAINER_URL', 'http://portainer.portainer.svc.cluster.local:9000')
        self.username = os.getenv('PORTAINER_USERNAME', 'admin')
        self.password = os.getenv('PORTAINER_PASSWORD', '')
        self._token = None
        self._authenticate()

    def _authenticate(self):
        """Authenticate and get JWT token."""
        response = requests.post(
            f'{self.base_url}/api/auth',
            json={'username': self.username, 'password': self.password}
        )
        response.raise_for_status()
        self._token = response.json()['jwt']

    def _request(self, method: str, endpoint: str, **kwargs) -> Any:
        """Make authenticated request to Portainer API."""
        headers = kwargs.pop('headers', {})
        headers['Authorization'] = f'Bearer {self._token}'

        url = f'{self.base_url}{endpoint}'
        response = requests.request(method, url, headers=headers, **kwargs)
        response.raise_for_status()
        return response.json()

    # Convenience methods

    def get_status(self) -> Dict:
        """Get Portainer server status."""
        return self._request('GET', '/api/status')

    def list_endpoints(self) -> List[Dict]:
        """List all endpoints (Docker/K8s environments)."""
        return self._request('GET', '/api/endpoints')

    def get_endpoint(self, endpoint_id: int) -> Dict:
        """Get specific endpoint details."""
        return self._request('GET', f'/api/endpoints/{endpoint_id}')

    def list_containers(self, endpoint_id: int = 1, all: bool = True) -> List[Dict]:
        """List containers in an endpoint."""
        params = {'all': 'true' if all else 'false'}
        return self._request('GET', f'/api/endpoints/{endpoint_id}/docker/containers/json', params=params)

    def get_container(self, endpoint_id: int, container_id: str) -> Dict:
        """Get container details."""
        return self._request('GET', f'/api/endpoints/{endpoint_id}/docker/containers/{container_id}/json')

    def list_stacks(self, endpoint_id: Optional[int] = None) -> List[Dict]:
        """List all stacks."""
        params = {}
        if endpoint_id:
            params['filters'] = f'{{"EndpointID":{endpoint_id}}}'
        return self._request('GET', '/api/stacks', params=params)

    def list_images(self, endpoint_id: int = 1) -> List[Dict]:
        """List Docker images."""
        return self._request('GET', f'/api/endpoints/{endpoint_id}/docker/images/json')

    def list_volumes(self, endpoint_id: int = 1) -> List[Dict]:
        """List Docker volumes."""
        return self._request('GET', f'/api/endpoints/{endpoint_id}/docker/volumes')

    def list_networks(self, endpoint_id: int = 1) -> List[Dict]:
        """List Docker networks."""
        return self._request('GET', f'/api/endpoints/{endpoint_id}/docker/networks')

    def container_stats(self, endpoint_id: int, container_id: str) -> Dict:
        """Get container stats (one-shot)."""
        return self._request('GET', f'/api/endpoints/{endpoint_id}/docker/containers/{container_id}/stats', params={'stream': 'false'})

    def container_logs(self, endpoint_id: int, container_id: str, tail: int = 100) -> str:
        """Get container logs."""
        # Note: logs endpoint returns text, not JSON
        headers = {'Authorization': f'Bearer {self._token}'}
        response = requests.get(
            f'{self.base_url}/api/endpoints/{endpoint_id}/docker/containers/{container_id}/logs',
            headers=headers,
            params={'stdout': 'true', 'stderr': 'true', 'tail': tail}
        )
        response.raise_for_status()
        return response.text

    def start_container(self, endpoint_id: int, container_id: str) -> None:
        """Start a container."""
        self._request('POST', f'/api/endpoints/{endpoint_id}/docker/containers/{container_id}/start')

    def stop_container(self, endpoint_id: int, container_id: str) -> None:
        """Stop a container."""
        self._request('POST', f'/api/endpoints/{endpoint_id}/docker/containers/{container_id}/stop')

    def restart_container(self, endpoint_id: int, container_id: str) -> None:
        """Restart a container."""
        self._request('POST', f'/api/endpoints/{endpoint_id}/docker/containers/{container_id}/restart')

    def exec_in_container(self, endpoint_id: int, container_id: str, cmd: List[str]) -> Dict:
        """Execute command in container (create exec instance)."""
        # Create exec instance
        exec_config = {
            'AttachStdout': True,
            'AttachStderr': True,
            'Cmd': cmd
        }
        exec_instance = self._request('POST', f'/api/endpoints/{endpoint_id}/docker/containers/{container_id}/exec', json=exec_config)

        # Start exec
        exec_id = exec_instance['Id']
        return self._request('POST', f'/api/endpoints/{endpoint_id}/docker/exec/{exec_id}/start', json={'Detach': False})


# Create global instance available as 'pc'
pc = PortainerClient()

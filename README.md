# SwiftGuard

My submission for the congressional app challenge 2026.

## Run locally

To develop the app locally, run:

```sh
docker compose up --build
```

This app requires docker to develop.

The two services you need to interact are:
- Flutter frontend: http://localhost:8081
- Django API health check: http://localhost:8000/api/

## Test data

The backend automatically generates test data when the docker containers are first created. The password is always `pass` for any user for testing purposes.


## Gemini API

Fill out a `.env` file in the same directory as `.env.example` to enable the app to use gemini to generate alert summaries (mainly the API key).
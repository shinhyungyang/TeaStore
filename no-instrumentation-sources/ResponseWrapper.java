package tools.descartes.teastore.registryclient.rest;

import jakarta.ws.rs.core.Response;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Wrapper for http responses.
 *
 * @author Simon
 *
 */
public final class ResponseWrapper {


  /**
   * Hide default constructor.
   */
  private ResponseWrapper() {

  }

  /**
   * Hook for monitoring.
   *
   * @param response
   *          response
   * @return response response
   */
  public static Response wrap(Response response) {
    return response;
  }

}

package tools.descartes.teastore.registryclient.rest;

import jakarta.ws.rs.client.Invocation.Builder;
import jakarta.ws.rs.core.MediaType;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import jakarta.ws.rs.client.WebTarget;

/**
 * Wrapper for http calls.
 *
 * @author Simon
 *
 */
public final class HttpWrapper {

  /**
   * Hide default constructor.
   */
  private HttpWrapper() {

  }

  /**
   * Wrap webtarget.
   *
   * @param target webtarget to wrap
   * @return wrapped wentarget
   */
  public static Builder wrap(WebTarget target) {
    Builder builder = target.request(MediaType.APPLICATION_JSON).accept(MediaType.APPLICATION_JSON);
    return builder;
  }
}

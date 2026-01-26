select * 
          
          rc_references:rc_references!rc_references_rate_confirmation_id_fkey(*),
          rc_stops:rc_stops!rc_stops_rate_confirmation_id_fkey(
            *,
            rc_commodities(*)
          ),
          rc_charges:rc_charges!rc_charges_rate_confirmation_id_fkey(*),
          rc_risk_clauses:rc_risk_clauses!rc_risk_clauses_rate_confirmation_id_fkey(
            *,
            rc_notifications(*)
          )
        ''').eq('id', id).maybeSingle();